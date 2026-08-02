defmodule ExMUSH.Network.Telnet do
  use ThousandIsland.Handler
  require Logger

  alias ThousandIsland.Socket
  alias ExMUSH.Network.{Session, SessionSupervisor}
  alias ExMUSH.Network.Telnet.IAC

  defmodule State do
    @enforce_keys [:session, :fd, :peer]
    defstruct(
      session: nil,
      fd: nil,
      peer: nil,
      mode: :data,
      data_buffer: [],
      iac_buffer: nil,
      unicode_in: false,
      unicode_out: false,
      terminal_type: nil
    )
  end

  @iac 255
  @iac_on_connect [
                    [:iac, :do, :naws],
                    [:iac, :do, :terminal_type],
                    [:iac, :do, :charset]
                  ]
                  |> Enum.map(&IAC.negotiate/1)

  @impl ThousandIsland.Handler
  def handle_connection(socket, _state) do
    peer = get_peer_name(socket)
    fd = get_socket_fd(socket)

    Logger.info("Received connection on #{fd} from #{peer}.")
    Socket.send(socket, @iac_on_connect)
    {:ok, session} = SessionSupervisor.start_session(self(), %{peer: peer, fd: fd})

    state = %State{
      peer: peer,
      fd: fd,
      session: session
    }

    {:continue, state}
  end

  @impl ThousandIsland.Handler
  def handle_close(_socket, state) do
    Logger.info("Lost connection on #{state.fd} from #{state.peer}.")
  end

  @impl ThousandIsland.Handler
  def handle_data("", _socket, state), do: {:continue, state}

  @impl ThousandIsland.Handler
  def handle_data(bytes, socket, %State{mode: :data} = state) do
    case :binary.match(bytes, [<<@iac>>, "\n"]) do
      :nomatch ->
        {:continue, %State{state | data_buffer: [bytes | state.data_buffer]}}

      {index, 1} ->
        <<chunk::binary-size(^index), byte, rest::binary>> = bytes
        state = handle_chunk(byte, chunk, socket, state)
        handle_data(rest, socket, state)
    end
  end

  @impl ThousandIsland.Handler
  def handle_data(bytes, socket, %State{mode: :iac, iac_buffer: buf} = state) do
    bytes = buf <> bytes

    case IAC.parse(bytes) do
      {:data, data, rest} ->
        %State{state | mode: :data, iac_buffer: nil, data_buffer: [data | state.data_buffer]}
        |> then(&handle_data(rest, socket, &1))

      {:command, iac, rest} ->
        %State{state | mode: :data, iac_buffer: nil}
        |> then(&handle_iac(iac, socket, &1))
        |> then(&handle_data(rest, socket, &1))

      :partial_command ->
        {:continue, %State{state | iac_buffer: bytes}}
    end
  end

  defp handle_chunk(?\n, chunk, socket, %State{data_buffer: buf} = state) do
    [chunk | buf]
    |> :erlang.iolist_to_binary()
    |> String.trim()
    |> dispatch_line(socket, state)

    %State{state | data_buffer: []}
  end

  defp handle_chunk(@iac, chunk, _socket, %State{} = state) do
    %State{state | data_buffer: [chunk | state.data_buffer], iac_buffer: <<@iac>>, mode: :iac}
  end

  defp dispatch_line(line, socket, state) do
    if state.unicode_out, do: Socket.send(socket, "\r")

    if check_printable?(line, state) do
      Session.input(state.session, line)
    else
      Socket.send(socket, "*** Line contains unprintable characters.  Discarded. ***\r\n")
    end
  end

  @impl GenServer
  def handle_info({:output, iodata}, {socket, state}) do
    [iodata, "\n"]
    |> IO.iodata_to_binary()
    |> String.replace("\n", "\r\n")
    |> to_output_encoding(state)
    |> then(&Socket.send(socket, &1))

    {:noreply, {socket, state}, socket.read_timeout}
  end

  @impl GenServer
  def handle_info({:EXIT, session, :normal}, {_socket, %State{session: session} = state}) do
    Logger.info("Closing connection on #{state.fd} from #{state.peer}.")
    {:stop, :normal, state}
  end

  defp to_output_encoding(output, %State{unicode_out: true}), do: output
  defp to_output_encoding(output, %State{unicode_out: false}), do: to_ascii(output)

  defp to_ascii(str) do
    str
    |> AnyAscii.transliterate()
    |> :erlang.iolist_to_binary()
  end

  defp get_peer_name(socket) do
    {:ok, {ip, port}} = Socket.peername(socket)
    "#{:inet.ntoa(ip)}:#{port}"
  end

  defp get_socket_fd(socket) do
    {:ok, fd} = :inet.getfd(socket.socket)
    fd
  end

  defp check_printable?(line, %State{unicode_in: true}),
    do: String.printable?(line) && !String.contains?(line, "\e")

  defp check_printable?(line, %State{unicode_in: false}), do: ascii_printable?(line)

  defp ascii_printable?(<<>>), do: true

  defp ascii_printable?(<<byte, rest::binary>>)
       when byte in 32..126 or byte == ?\t,
       do: ascii_printable?(rest)

  defp ascii_printable?(_), do: false

  # Client requests a visible indicator of life.
  # It's silly and nobody's going to use this, but meh, easy to do.
  defp handle_iac([:iac, :are_you_there], socket, state) do
    Socket.send(socket, "*** Server is up ***\r\n")
    state
  end

  defp handle_iac([:iac, :will, :naws], _socket, state), do: state

  defp handle_iac([:iac, :will, :terminal_type], socket, %State{} = state) do
    case state.terminal_type do
      nil ->
        Socket.send(socket, IAC.request_terminal_type())
        %State{state | terminal_type: :pending}

      _ ->
        state
    end
  end

  defp handle_iac([:iac, :will, :transmit_binary], _socket, %State{} = state) do
    Logger.debug("Client #{state.fd} agrees to send binary data")
    %State{state | unicode_in: true}
  end

  defp handle_iac([:iac, :wont, :transmit_binary], _socket, %State{} = state) do
    Logger.debug("Client #{state.fd} refuses to send binary data")
    state
  end

  defp handle_iac([:iac, :do, :transmit_binary], _socket, %State{} = state) do
    Logger.debug("Client #{state.fd} agrees to receive binary data")
    %State{state | unicode_out: true}
  end

  defp handle_iac([:iac, :dont, :transmit_binary], _socket, %State{} = state) do
    Logger.debug("Client #{state.fd} refuses to receive binary data")
    state
  end

  defp handle_iac([:iac, :will, :charset], socket, %State{} = state) do
    Logger.debug("Client #{state.fd} begins charset negotiation")
    Socket.send(socket, IAC.offer_utf8_charset())
    state
  end

  defp handle_iac([:iac, :wont, :charset], socket, %State{} = state) do
    Logger.debug("Client #{state.fd} refuses charset negotiation, trying binary")

    [
      [:iac, :do, :transmit_binary],
      [:iac, :will, :transmit_binary]
    ]
    |> Enum.map(&IAC.negotiate/1)
    |> then(&Socket.send(socket, &1))

    state
  end

  defp handle_iac([:iac, :will, capab] = iac, socket, %State{} = state) do
    Logger.warning("Refusing #{state.fd} unknown client capability: #{inspect(iac)}")
    Socket.send(socket, [:iac, :dont, capab] |> IAC.negotiate())
    state
  end

  defp handle_iac([:iac, :do, capab] = iac, socket, %State{} = state) do
    unless capab == :timing_mark do
      Logger.warning("Refusing #{state.fd} unknown server capability: #{inspect(iac)}")
    end

    Socket.send(socket, [:iac, :wont, capab] |> IAC.negotiate())
    state
  end

  defp handle_iac([:iac, :subopt, :naws, {w, h}], _socket, %State{} = state) do
    Logger.debug("Client #{state.fd} terminal size: #{w}x#{h}")
    state
  end

  defp handle_iac([:iac, :subopt, :terminal_type, type], _socket, %State{} = state) do
    Logger.debug("Client #{state.fd} terminal type: #{inspect(type)}")
    state
  end

  defp handle_iac([:iac, :subopt, :charset, {:accepted, "UTF-8"}], _, %State{} = state) do
    Logger.debug("Client #{state.fd} accepts UTF-8 encoding")
    %State{state | unicode_in: true, unicode_out: true}
  end

  # Common keys: ctrl-\, ctrl-C, ctrl-Z
  defp handle_iac([:iac, :break], _, state), do: state
  defp handle_iac([:iac, :interrupt], _, state), do: state
  defp handle_iac([:iac, :suspend], _, state), do: state

  defp handle_iac(iac, _socket, state) do
    Logger.debug("Client #{state.fd} sent unknown IAC command: #{inspect(iac)}")
    state
  end
end
