defmodule ExMUSH.ActionList.Supervisor do
  use DynamicSupervisor

  alias ExMUSH.ActionList
  alias ExMUSH.Context

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def run_list(%ActionList{} = list, %Context{} = ctx) do
    DynamicSupervisor.start_child(__MODULE__, ActionList.child_spec(list, ctx))
  end
end
