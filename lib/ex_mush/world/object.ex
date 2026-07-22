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

  defdelegate get(obj_id), to: ObjectDirectory

  [:owner, :parent, :location, :link]
  |> Enum.each(fn key ->
    defdelegate unquote(key)(obj_id), to: ObjectDirectory
    defdelegate unquote(:"#{key}_id")(obj_id), to: ObjectDirectory
  end)

  defdelegate attribute(obj_id, attr_name), to: ObjectServer
end
