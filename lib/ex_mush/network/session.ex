defmodule ExMUSH.Network.Session do
  use GenServer
  import ExMUSH
  alias ExMUSH.Command
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
    do_output(Command.Login.motd(), state)
    {:ok, state}
  end

  @impl true
  def handle_cast({:input, line}, %State{player_oid: nil} = state) do
    with {:ok, cmd} <- Command.Login.parse(line) do
      case Command.Login.execute(cmd, &do_output(&1, state)) do
        :close -> {:stop, :normal}
        {:connected, oid} -> {:noreply, do_connect(oid, state)}
        :ok -> {:noreply, state}
      end
    else
      _ ->
        do_output(Command.Login.motd(), state)
        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:input, line}, %State{player_oid: oid} = state) when is_object_id(oid) do
    # FIXME: this is EXTREMELY temporary
    #  - add commands to per-session queue
    #    - eventually TODO: handle queue overrun
    #  - push one command at a time to the player's object's command queue process
    #  - wait for finish, send the next command
    case Command.Parser.parse(line) do
      {:ok, %Command.Prepared{} = prepared} ->
        Command.Prepared.execute(prepared, Command.State.for_player(oid))

      {:error, _} = err ->
        err
        |> inspect(pretty: true)
        |> do_output(state)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:output, iodata}, state) do
    do_output(iodata, state)
    {:noreply, state}
  end

  defp do_output(iodata, %State{net_pid: pid}) do
    send(pid, {:output, iodata})
    :ok
  end

  defp do_connect(new_oid, %State{player_oid: nil, conn_info: info} = state) do
    SessionRegistry.register(new_oid, info)
    %State{state | player_oid: new_oid}
  end
end
