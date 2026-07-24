defmodule ExMUSH.DB.Repo do
  use Ecto.Repo,
    otp_app: :ex_mush,
    adapter: Ecto.Adapters.Postgres

  alias __MODULE__
  alias ExMUSH.DB.Object
  import Ecto.Query, only: [from: 2]

  def get_objects_for_directory do
    from(obj in Object,
      left_join: attr in assoc(obj, :attributes),
      on: attr.name == "ALIAS",
      preload: [attributes: attr]
    )
    |> Repo.all()
  end
end
