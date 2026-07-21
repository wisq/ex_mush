defmodule ExMUSH.DB.Object.Attribute do
  use Ecto.Schema
  alias ExMUSH.DB.Object

  schema "object_attributes" do
    timestamps(type: :utc_datetime_usec)

    belongs_to(:object, Object)
    field(:name, :string)
    field(:value, :string)

    belongs_to(:owner, Object)
    field(:flags, {:array, Ecto.Enum}, values: [])
  end
end
