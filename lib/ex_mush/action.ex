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
        %Context{player: player} = ctx
      ) do
    try do
      apply(mod, fun, [ctx, switches] ++ args)
    rescue
      exception ->
        %type{} = exception

        command =
          case cmd_name do
            nil -> "command"
            n when is_binary(n) -> "#{inspect(n)} command"
          end

        Object.tell(player, [
          "Your #{command} failed with #{inspect(type)}.  ",
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
