defmodule ExMUSH.DB.Object.Attribute do
  use Ecto.Schema
  alias ExMUSH.DB
  alias ExMUSH.World
  alias ExMUSH.ObjectID, as: OID

  schema "object_attributes" do
    timestamps(type: :utc_datetime_usec)

    belongs_to(:object, DB.Object)
    field(:name, :string)
    field(:value, :string)

    belongs_to(:owner, DB.Object)
    field(:flags, {:array, Ecto.Enum}, values: [])
  end

  @spec to_world(%DB.Object.Attribute{}) :: %World.Object.Attribute{}
  def to_world(%DB.Object.Attribute{} = attr) do
    %World.Object.Attribute{
      name: attr.name,
      owner_oid: OID.from_db(attr.owner_id),
      flags: MapSet.new(attr.flags),
      value: attr.value
    }
  end

  @spec from_world(%World.Object.Attribute{}) :: keyword()
  def from_world(%World.Object.Attribute{} = attr) do
    [
      name: attr.name,
      owner_id: OID.to_db(attr.owner_oid),
      flags: Enum.to_list(attr.flags),
      value: attr.value
    ]
  end
end
