defmodule ExMUSH.Command.Basic do
  use ExMUSH.Command
  alias ExMUSH.World.Object
  alias ExMUSH.World.Matching

  @command "look"
  @aliases ["l"]
  @switches ["outside"]
  @parser :one_arg

  defcommand look(state, _switches, target \\ "here") do
    case Matching.locate(state.executor, target, %Matching.Opts{location: false}) do
      {:ok, oid} ->
        Object.tell(state.executor, "You look at #{Object.get(oid).name} (#{oid}).")

      {:error, :no_match} ->
        Object.tell(state.executor, "I don't see that here.")

      {:error, :ambiguous_match} ->
        Object.tell(state.executor, "I'm not sure which one you mean.")
    end
  end

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
