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

  def handle(%Context{player: player} = ctx, _, input) do
    case Matching.locate(player, input, MOpts.only(nearby_exits: true, exact_match: true)) do
      {:ok, %Object{type: :exit} = exit} -> traverse_exit(ctx, player, exit)
      {:error, :ambiguous_match} -> Object.tell(player, "I don't know which way you mean!")
      {:error, :no_match} -> Object.tell(player, ~s{Huh?  (Type "help" for help.)})
    end
  end

  defp traverse_exit(
         %Context{},
         %Object{oid: player_oid},
         %Object{location_oid: from, link_oid: to}
       ) do
    case ExMUSH.World.ObjectDirectory.move(player_oid, from, to) do
      {:ok, _} -> :ok
      {:error, _} -> Object.tell(player_oid, "You can't go that way.")
    end
  end
end
