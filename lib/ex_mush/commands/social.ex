defmodule ExMUSH.Commands.Social do
  use ExMUSH.Command
  alias ExMUSH.Context
  alias ExMUSH.World.Object

  @command "say"
  @aliases [~s'"']
  # TODO: @switches ["noeval"]
  @parser :one_arg

  defcommand say(%Context{player: player}, _switches, message \\ "") do
    Object.tell(player, ~s'You say, "#{message}"')
    Object.announce(player, ~s'#{player.name} says, "#{message}"')
  end

  @command "pose"
  @aliases [":"]
  # TODO: also "noeval"
  @switches ["nospace"]
  @parser :one_arg

  def pose(ctx, switches, message \\ "")

  defcommand pose(%Context{player: player}, %{nospace: false}, message) do
    Object.announce_all(player, ~s'#{player.name} #{message}')
  end

  defcommand pose(%Context{player: player}, %{nospace: true}, message) do
    Object.announce_all(player, ~s'#{player.name}#{message}')
  end
end
