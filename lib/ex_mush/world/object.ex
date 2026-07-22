defmodule ExMUSH.World.Object do
  alias __MODULE__
  alias ExMUSH.DB
  alias ExMUSH.World.{ObjectDirectory, ObjectServer}

  @enforce_keys [:id, :name, :type, :flags, :owner_id, :parent_id, :location_id, :link_id]
  defstruct(@enforce_keys)

  defmodule Attribute do
    @enforce_keys [:name, :owner_id, :flags, :value]
    defstruct(@enforce_keys)
  end

  def load(%DB.Object{} = obj) do
    Map.from_struct(obj)
    |> Map.take(@enforce_keys)
    |> then(&struct!(Object, &1))
  end

  defdelegate owner_id(obj_id), to: ObjectDirectory
  defdelegate parent_id(obj_id), to: ObjectDirectory
  defdelegate location_id(obj_id), to: ObjectDirectory
  defdelegate link_id(obj_id), to: ObjectDirectory
  defdelegate contents(obj_id), to: ObjectDirectory

  defdelegate attribute(obj_id, attr_name), to: ObjectServer
end
