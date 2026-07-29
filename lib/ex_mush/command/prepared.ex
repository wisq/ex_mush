defmodule ExMUSH.Command.Prepared do
  @enforce_keys [:command, :switches, :args]
  defstruct(@enforce_keys)

  alias ExMUSH.Command

  def execute(
        %Command.Prepared{
          command: %Command{
            execute: {mod, fun}
          },
          switches: switches,
          args: args
        },
        %Command.State{} = state
      ) do
    apply(mod, fun, [state, switches] ++ args)
  end
end
