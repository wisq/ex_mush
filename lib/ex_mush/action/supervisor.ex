defmodule ExMUSH.Action.Supervisor do
  use DynamicSupervisor

  alias ExMUSH.Action
  alias ExMUSH.Context

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def run(%Action{} = action, %Context{} = ctx) do
    {:ok, pid} = DynamicSupervisor.start_child(__MODULE__, Action.child_spec(action, ctx))
    Process.monitor(pid)

    receive do
      {:DOWN, _, :process, ^pid, reason} -> {:ok, reason}
    end
  end
end
