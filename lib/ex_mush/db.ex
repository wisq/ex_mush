defmodule ExMUSH.DB do
  import Ecto.Query, only: [from: 2]
  alias ExMUSH.DB.Repo
  alias ExMUSH.DB.Object

  def fetch_object(id) do
    from(o in Object, where: o.id == ^id, preload: :attributes)
    |> Repo.one()
    |> then(fn
      %Object{} = obj -> {:ok, obj}
      nil -> {:error, :object_not_found}
    end)
  end
end
