defmodule ExMUSH.Command.Unknown do
  alias ExMUSH.Context
  alias ExMUSH.Command
  alias ExMUSH.World.Object
  alias ExMUSH.World.Matching
  alias ExMUSH.World.Matching.Opts, as: MOpts

  @command %Command{
    name: nil,
    aliases: [],
    switches: [],
    parser: nil,
    execute: {__MODULE__, :handle}
  }

  def command, do: @command

  def handle(%Context{player: player}, _, input) do
    case Matching.locate(player, input, MOpts.only(nearby_exits: true, exact_match: true)) do
      {:ok, %Object{type: :exit} = exit} -> traverse_exit(player, exit)
      {:error, :ambiguous_match} -> Object.tell(player, "I don't know which way you mean!")
      {:error, :no_match} -> Object.tell(player, ~s{Huh?  (Type "help" for help.)})
    end
  end

  defp traverse_exit(player, exit) do
    Object.tell(player, "You try to go #{exit.name} but exits don't work yet.")
  end
end
