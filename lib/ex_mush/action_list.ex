defmodule ExMUSH.ActionList do
  @enforce_keys [:actions]
  defstruct(@enforce_keys)

  alias __MODULE__
  alias ExMUSH.Action
  alias ExMUSH.Context

  def new([%Action{} | _] = actions) do
    %ActionList{actions: actions}
  end

  def child_spec(%ActionList{} = list, %Context{} = ctx) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [list, ctx]},
      restart: :temporary
    }
  end

  def start_link(%ActionList{} = list, %Context{} = ctx) do
    pid = spawn_link(__MODULE__, :run, [list, ctx])
    {:ok, pid}
  end

  def run(%ActionList{actions: actions}, %Context{} = ctx) do
    actions
    |> Enum.each(&Action.Supervisor.run(&1, ctx))
  end
end
