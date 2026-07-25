defmodule ExMUSH.Network.Session do
  use GenServer
  alias ExMUSH.Command

  def child_spec(opts) do
    super(opts)
    |> Map.put(:restart, :temporary)
  end

  def start_link(opts) do
    {net_pid, opts} = Keyword.pop!(opts, :net_pid)
    GenServer.start_link(__MODULE__, net_pid, opts)
  end

  def input(pid, line), do: GenServer.cast(pid, {:input, line})
  def output(pid, iodata), do: GenServer.cast(pid, {:output, iodata})

  defmodule State do
    @enforce_keys [:net_pid]
    defstruct(
      net_pid: nil,
      player_oid: nil
    )
  end

  @impl true
  def init(net_pid) do
    Process.link(net_pid)
    state = %State{net_pid: net_pid}
    do_output(Command.Login.motd(), state)
    {:ok, state}
  end

  @impl true
  def handle_cast({:input, line}, %State{player_oid: nil} = state) do
    with {:ok, cmd} <- Command.Login.parse(line) do
      case Command.Login.execute(cmd, &do_output(&1, state)) do
        :close -> {:stop, :normal}
        {:connected, oid} -> {:noreply, %State{state | player_oid: oid}}
        :ok -> {:noreply, state}
      end
    else
      _ ->
        do_output(Command.Login.motd(), state)
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:input, line}, state) do
    IO.inspect(line, label: "input")
    do_output("You sent: #{inspect(line)}", state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:output, iodata}, state) do
    IO.inspect(iodata, label: "output")
    do_output(iodata, state)
    {:noreply, state}
  end

  defp do_output(iodata, %State{net_pid: pid}) do
    send(pid, {:output, iodata})
    :ok
  end
end
