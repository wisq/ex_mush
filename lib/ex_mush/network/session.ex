defmodule ExMUSH.Network.Session do
  use GenServer

  def child_spec(opts) do
    super(opts)
    |> Map.put(:restart, :temporary)
  end

  def start_link(opts) do
    {net_pid, opts} = Keyword.pop!(opts, :net_pid)
    GenServer.start_link(__MODULE__, net_pid, opts)
  end

  def receive_line(pid, line) do
    GenServer.cast(pid, {:receive_line, line})
  end

  defmodule State do
    @enforce_keys [:net_pid]
    defstruct(@enforce_keys)
  end

  @impl true
  def init(net_pid) do
    Process.link(net_pid)
    {:ok, %State{net_pid: net_pid}}
  end

  @impl true
  def handle_cast({:receive_line, line}, state) do
    IO.inspect(line, label: "receive_line")
    {:noreply, state}
  end
end
