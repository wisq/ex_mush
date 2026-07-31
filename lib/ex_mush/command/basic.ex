defmodule ExMUSH.Command.Basic do
  use ExMUSH.Command
  alias ExMUSH.World.Object

  @command "@teleport"
  @switches ~w"list inside silent"
  @parser :two_args

  defcommand teleport(state, switches) do
    Object.tell(
      state.executor,
      inspect({state, switches}, label: "@teleport without args", pretty: true)
    )
  end

  defcommand teleport(state, switches, object \\ "me", destination) do
    Object.tell(
      state.executor,
      inspect({state, switches, object, destination}, label: "@teleport", pretty: true)
    )
  end
end
