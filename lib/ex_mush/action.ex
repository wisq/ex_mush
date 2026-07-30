defmodule ExMUSH.Action do
  @enforce_keys [:command, :switches, :args]
  defstruct(@enforce_keys)

  alias __MODULE__
  alias ExMUSH.Command
  alias ExMUSH.Context

  def execute(
        %Action{
          command: %Command{
            execute: {mod, fun}
          },
          switches: switches,
          args: args
        },
        %Context{} = ctx
      ) do
    apply(mod, fun, [ctx, switches] ++ args)
  end

  def child_spec(%Action{} = action, %Context{} = ctx) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [action, ctx]},
      restart: :temporary
    }
  end

  def start_link(%Action{} = action, %Context{} = ctx) do
    pid = spawn_link(__MODULE__, :execute, [action, ctx])
    {:ok, pid}
  end
end
