defmodule ExMUSH.Commands.Teleport do
  use ExMUSH.Command
  alias ExMUSH.World.Object

  @command "@teleport"
  @switches ~w"list inside silent"
  @parser :two_args

  defcommand teleport(state, switches) do
    Object.tell(
      state.player,
      inspect({state, switches}, label: "@teleport without args", pretty: true)
    )
  end

  defcommand teleport(state, switches, object \\ "me", destination) do
    Object.tell(
      state.player,
      inspect({state, switches, object, destination}, label: "@teleport", pretty: true)
    )
  end
end
