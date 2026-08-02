defmodule ExMUSH.Network.Telnet do
  use ThousandIsland.Handler
  require Logger

  alias ThousandIsland.Socket
  alias ExMUSH.Network.{Session, SessionSupervisor}

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

  defmodule IAC do
    @iac 255
    @subopt_begin 250
    @subopt_end 240

    @naws 31
    @terminal_type 24
    @charset 42

    @negotiation [
      will: 251,
      wont: 252,
      do: 253,
      dont: 254
    ]

    @capabilities [
      naws: @naws,
      terminal_type: @terminal_type,
      transmit_binary: 0,
      charset: @charset,
      echo: 1,
      suppress_go_ahead: 3
    ]

    @commands [
      noop: 241,
      interrupt: 244,
      abort: 245,
      are_you_there: 246,
      erase_char: 247,
      erase_line: 248
    ]

    @atoms_to_bytes [
                      [iac: @iac],
                      @negotiation,
                      @capabilities,
                      @commands
                    ]
                    |> Enum.reduce(&Kernel.++/2)
                    |> Map.new()

    @bytes_to_atoms Map.new(@atoms_to_bytes, fn {k, v} -> {v, k} end)

    def to_bytes(atoms) do
      atoms
      |> Enum.map(fn cmd ->
        byte = Map.fetch!(@atoms_to_bytes, cmd)
        <<byte>>
      end)
    end

    def request_terminal_type do
      <<@iac, @subopt_begin, @terminal_type, 1, @iac, @subopt_end>>
    end

    def offer_utf8_charset do
      <<@iac, @subopt_begin, @charset, 1, 1, "UTF-8", @iac, @subopt_end>>
    end

    def parse(<<@iac, @iac, rest::binary>>), do: {:data, <<@iac>>, rest}

    @command_bytes Keyword.values(@commands)
    def parse(<<@iac, byte, rest::binary>>) when byte in @command_bytes do
      atom = Map.fetch!(@bytes_to_atoms, byte)
      {:command, [:iac, atom], rest}
    end

    @negotiation_bytes Keyword.values(@negotiation)
    @capability_bytes Keyword.values(@capabilities)
    def parse(<<@iac, n_byte, c_byte, rest::binary>>)
        when n_byte in @negotiation_bytes and c_byte in @capability_bytes do
      n_atom = Map.fetch!(@bytes_to_atoms, n_byte)
      c_atom = Map.fetch!(@bytes_to_atoms, c_byte)
      {:command, [:iac, n_atom, c_atom], rest}
    end

    def parse(<<@iac, @subopt_begin, rest::binary>>) do
      case read_subopt(rest) do
        {:complete, subopt, rest} ->
          {:command, [:iac, :subopt | parse_subopt(subopt)], rest}

        :incomplete ->
          :partial_command
      end
    end

    # We can't just assume any unknown command is incomplete, since then we'd
    # be buffering IAC commands forever.
    #
    # Instead, we only match known incomplete commands:
    #  - IAC with nothing after it
    def parse(<<@iac>>), do: :partial_command
    #  - IAC negotiation with no capability
    def parse(<<@iac, n_byte>>) when n_byte in @negotiation_bytes, do: :partial_command

    defp parse_subopt(<<@naws, width::integer-size(16), height::integer-size(16)>>) do
      [:naws, {width, height}]
    end

    defp parse_subopt(<<@terminal_type, 0, type::binary>>) do
      [:terminal_type, type]
    end

    defp parse_subopt(<<@charset, 2, encoding::binary>>) do
      [:charset, {:accepted, encoding}]
    end

    defp parse_subopt(<<@charset, 3, encoding::binary>>) do
      [:charset, {:rejected, encoding}]
    end

    defp read_subopt(bytes, buffer \\ []) do
      case :binary.match(bytes, <<@iac>>) do
        :nomatch ->
          :incomplete

        {index, 1} ->
          <<chunk::binary-size(^index), match::binary>> = bytes

          case match do
            <<@iac, @iac, rest::binary>> ->
              read_subopt(rest, [<<@iac>>, chunk | buffer])

            <<@iac, @subopt_end, rest::binary>> ->
              {
                :complete,
                [chunk | buffer] |> Enum.reverse() |> :erlang.iolist_to_binary(),
                rest
              }
          end
      end
    end
  end

  @iac 255
  @iac_on_connect [
                    [:iac, :do, :naws],
                    [:iac, :do, :terminal_type],
                    [:iac, :wont, :echo],
                    [:iac, :do, :charset]
                  ]
                  |> Enum.map(&IAC.to_bytes/1)

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
    |> String.to_charlist()
    |> Enum.map(fn
      c when c <= 127 -> c
      _ -> ??
    end)
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
    |> Enum.map(&IAC.to_bytes/1)
    |> then(&Socket.send(socket, &1))

    state
  end

  defp handle_iac([:iac, :will, other] = iac, socket, %State{} = state) do
    Logger.warning("Refusing #{state.fd} unknown client capability: #{inspect(iac)}")
    Socket.send(socket, [:iac, :dont, other] |> IAC.to_bytes())
    state
  end

  defp handle_iac([:iac, :do, other] = iac, socket, %State{} = state) do
    Logger.warning("Refusing #{state.fd} unknown server capability: #{inspect(iac)}")
    Socket.send(socket, [:iac, :wont, other] |> IAC.to_bytes())
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

  defp handle_iac(unknown, _socket, state) do
    IO.inspect(unknown, label: "IAC")
    state
  end
end
