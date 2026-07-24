defmodule ExMUSH.Network.Telnet do
  use ThousandIsland.Handler
  require Logger

  alias ThousandIsland.Socket
  alias ExMUSH.Network.{Session, SessionSupervisor}

  defmodule State do
    @enforce_keys [:session, :fd, :peer]
    defstruct(
      Enum.map(@enforce_keys, &{&1, nil}) ++
        [
          buffer: <<>>
        ]
    )
  end

  def send_message(pid, msg) do
    GenServer.cast(pid, {:send, msg})
  end

  @impl true
  def handle_connection(socket, _state) do
    peer = get_peer_name(socket)
    fd = get_socket_fd(socket)

    Logger.info("Received connection on #{fd} from #{peer}.")
    {:ok, session} = SessionSupervisor.start_session(self())

    state = %State{
      peer: peer,
      fd: fd,
      session: session
    }

    {:continue, state}
  end

  @impl true
  def handle_close(_socket, state) do
    Logger.info("Lost connection on #{state.fd} from #{state.peer}.")
  end

  @impl true
  def handle_data(msg, socket, state) do
    msg
    |> String.split(~r/\r?\n/, trim: false)
    |> dispatch_lines(state, socket)
    |> then(fn %State{} = state ->
      {:continue, state}
    end)
  end

  defp dispatch_lines([last], %State{buffer: buf} = state, _) do
    %State{state | buffer: buf <> last}
  end

  defp dispatch_lines([line | rest], %State{buffer: buf, session: sess} = state, socket) do
    {line, state} =
      case buf do
        <<>> -> {line, state}
        b -> {b <> line, %State{state | buffer: <<>>}}
      end

    if check_printable?(line, state) do
      Session.receive_line(sess, line)
    else
      Socket.send(socket, "*** Line contains unprintable characters.  Discarded. ***")
    end

    dispatch_lines(rest, %State{state | buffer: <<>>}, socket)
  end

  @impl GenServer
  def handle_cast({:send, msg}, {socket, state}) do
    Socket.send(socket, msg)
    {:noreply, {socket, state}, socket.read_timeout}
  end

  defp get_peer_name(socket) do
    {:ok, {ip, port}} = Socket.peername(socket)
    "#{:inet.ntoa(ip)}:#{port}"
  end

  defp get_socket_fd(socket) do
    {:ok, fd} = :inet.getfd(socket.socket)
    fd
  end

  defp check_printable?(line, _state) do
    # TODO: scan line based on input charset
    #   - UTF-8: String.printable?/1
    #   - ASCII: List.ascii_printable?/1
    String.printable?(line)
  end
end
