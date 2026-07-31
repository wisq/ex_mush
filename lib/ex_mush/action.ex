defmodule ExMUSH.Action do
  @enforce_keys [:command, :switches, :args]
  defstruct(@enforce_keys)

  alias __MODULE__
  alias ExMUSH.Command
  alias ExMUSH.Context
  alias ExMUSH.World.Object

  def execute(
        %Action{
          command: %Command{
            name: cmd_name,
            execute: {mod, fun}
          },
          switches: switches,
          args: args
        },
        %Context{executor: player} = ctx
      ) do
    try do
      apply(mod, fun, [ctx, switches] ++ args)
    rescue
      exception ->
        %type{} = exception

        Object.tell(player, [
          "Your #{inspect(cmd_name)} command failed with #{inspect(type)}.  ",
          "Check server logs for details."
        ])

        raise exception
    end
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
