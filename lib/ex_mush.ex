defmodule ExMUSH do
  use Application

  def start(_type, _args) do
    [
      ExMUSH.DB.Repo
    ]
    |> Supervisor.start_link(
      strategy: :one_for_one,
      name: ExMUSH.Supervisor
    )
  end
end
