defmodule ExMUSH.Network.Session do
  use GenServer
  alias ExMUSH.ObjectID, as: OID
  alias ExMUSH.Command
  alias ExMUSH.Context
  alias ExMUSH.Action
  alias ExMUSH.Network.SessionRegistry

  def child_spec(opts) do
    super(opts)
    |> Map.put(:restart, :temporary)
  end

  def start_link(opts) do
    {net_pid, opts} = Keyword.pop!(opts, :net_pid)
    {conn_info, opts} = Keyword.pop!(opts, :conn_info)
    GenServer.start_link(__MODULE__, {net_pid, conn_info}, opts)
  end

  def input(pid, line), do: GenServer.cast(pid, {:input, line})
  def output(pid, iodata), do: GenServer.cast(pid, {:output, iodata})

  defmodule State do
    @enforce_keys [:net_pid, :conn_info]
    defstruct(
      net_pid: nil,
      conn_info: nil,
      player_oid: nil
    )
  end

  @impl true
  def init({net_pid, conn_info}) do
    Process.link(net_pid)
    state = %State{net_pid: net_pid, conn_info: conn_info}
    {:ok, show_motd(state)}
  end

  @impl true
  def handle_cast({:input, "QUIT"}, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({:input, "LOGOUT"}, %State{player_oid: %OID{}} = state) do
    state
    |> do_logout()
    |> show_motd()
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_cast({:input, line}, %State{player_oid: nil} = state) do
    with {:ok, cmd} <- Command.Login.parse(line) do
      case Command.Login.execute(cmd, &do_output(&1, state)) do
        {:connected, oid} -> {:noreply, do_connect(oid, state)}
        :ok -> {:noreply, state}
      end
    else
      _ -> {:noreply, show_motd(state)}
    end
  end

  @impl true
  def handle_cast({:input, line}, %State{player_oid: %OID{} = oid} = state) do
    line = String.trim(line)

    if line != "" do
      {:ok, _} =
        Command.Parser.parse(line)
        |> Action.Supervisor.run(Context.for_player(oid))
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:output, iodata}, state) do
    do_output(iodata, state)
    {:noreply, state}
  end

  defp show_motd(%State{} = state) do
    do_output(Command.Login.motd(), state)
    state
  end

  defp do_output(iodata, %State{net_pid: pid}) do
    send(pid, {:output, iodata})
    :ok
  end

  defp do_logout(%State{player_oid: %OID{} = oid} = state) do
    SessionRegistry.unregister(oid)
    %State{state | player_oid: nil}
  end

  defp do_connect(new_oid, %State{player_oid: nil, conn_info: info} = state) do
    SessionRegistry.register(new_oid, info)
    on_connect(new_oid)
    %State{state | player_oid: new_oid}
  end

  defp on_connect(oid) do
    Command.Parser.parse("look")
    |> Action.Supervisor.run(Context.for_player(oid))
  end
end
