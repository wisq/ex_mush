defmodule ExMUSH.DB do
  import Ecto.Query, only: [from: 2]
  alias ExMUSH.DB.Repo
  alias ExMUSH.DB.Object
  # alias ExMUSH.DB.Object.Attribute

  def get_object(id) do
    from(o in Object, where: o.id == ^id, preload: :attributes)
    |> Repo.one()
  end
end
