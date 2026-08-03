defmodule ExMUSH.Commands.Emit do
  use ExMUSH.Command
  alias ExMUSH.Context
  alias ExMUSH.World.Object
  alias ExMUSH.World.Matching

  @command "@emit"
  @aliases ["\\"]
  # TODO: @switches ["noeval", "spoof"]
  @parser :one_arg

  defcommand say(%Context{player: player}, _switches, message \\ "") do
    Object.announce_all(player, message)
  end

  @command "@pemit"
  # TODO: @switches ~w"list port contents silent noisy noeval spoof", oh my
  @parser :two_args

  def pemit(context, switches, target \\ nil, message \\ "")

  defcommand(pemit(%Context{}, _switches, _, ""), do: :noop)

  defcommand pemit(%Context{player: player}, _switches, target_name, message) do
    player_oid = player.oid

    case Matching.locate(player, target_name) do
      {:ok, %Object{oid: ^player_oid} = target} ->
        Object.tell(target, message)

      {:ok, %Object{} = target} ->
        Object.tell(target, message)
        Object.tell(player, ~s'You pemit "#{message}" to #{target.name}.')

      {:error, :no_match} ->
        Object.tell(player, "I don't see that here.")

      {:error, :ambiguous_match} ->
        Object.tell(player, "I don't know which one you mean!")
    end
  end

  @command "@oemit"
  # TODO: read the help file, there's a whole lot of functionality missing here
  @parser :two_args

  def oemit(context, switches, target \\ nil, message \\ "")

  defcommand(oemit(%Context{}, _switches, _, ""), do: :noop)

  defcommand oemit(%Context{player: player}, _switches, target_name, message) do
    case Matching.locate(player, target_name) do
      {:ok, target} -> Object.announce(target, message)
      {:error, :no_match} -> Object.tell(player, "I don't see that here.")
      {:error, :ambiguous_match} -> Object.tell(player, "I don't know which one you mean!")
    end
  end
end
