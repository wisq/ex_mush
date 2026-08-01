defmodule ExMUSH.Commands.Teleport do
  use ExMUSH.Command
  alias ExMUSH.Context
  alias ExMUSH.World.Object
  alias ExMUSH.World.Matching

  @command "@teleport"
  @switches ~w"list inside silent"
  @parser :two_args

  defcommand teleport(%Context{player: player}, _switches) do
    Object.tell(player, "Teleport where?")
  end

  defcommand teleport(%Context{player: player}, _switches, whatstr \\ "me", wherestr) do
    with {:ok, what} <- Matching.locate(player, whatstr),
         {:ok, where} <- Matching.locate(player, wherestr),
         {:ok, _} <- Object.move(what, where) do
      # TODO
      # - teleport to exits
      # - teleport home
      # - permission checks
      Object.tell(player, "Teleported.")
    end
  end
end
