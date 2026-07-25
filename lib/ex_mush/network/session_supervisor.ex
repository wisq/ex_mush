defmodule ExMUSH.Network.SessionSupervisor do
  use DynamicSupervisor

  alias ExMUSH.Network.Session

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_session(net_pid) when is_pid(net_pid) do
    DynamicSupervisor.start_child(__MODULE__, {Session, net_pid: net_pid})
  end
end
