defmodule ExMUSH.Command.Basic do
  use ExMUSH.Command

  @command "look"
  @aliases ["l"]
  @switches ["outside"]
  @parser :one_arg

  defcommand look(state, switches, target \\ "here") do
    IO.inspect({state, switches, target}, label: "look")
  end

  @command "@teleport"
  @switches ~w"list inside silent"
  @parser :two_args

  defcommand teleport(state, switches) do
    IO.inspect({state, switches}, label: "@teleport without args")
  end

  defcommand teleport(state, switches, object \\ "me", destination) do
    IO.inspect({state, switches, object, destination}, label: "@teleport")
  end
end
