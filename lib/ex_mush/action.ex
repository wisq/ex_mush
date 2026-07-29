defmodule ExMUSH.Action do
  @enforce_keys [:command, :switches, :args]
  defstruct(@enforce_keys)

  alias __MODULE__
  alias ExMUSH.Command

  def execute(
        %Action{
          command: %Command{
            execute: {mod, fun}
          },
          switches: switches,
          args: args
        },
        %Action.State{} = state
      ) do
    apply(mod, fun, [state, switches] ++ args)
  end
end
