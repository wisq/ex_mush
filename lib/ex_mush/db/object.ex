defmodule ExMUSH.DB.Object do
  use Ecto.Schema
  alias ExMUSH.DB
  alias ExMUSH.World.Object.Flags

  schema "objects" do
    timestamps(type: :utc_datetime_usec)

    field(:name, :string)
    field(:type, Ecto.Enum, values: [:room, :thing, :exit, :player, :garbage])
    field(:flags, {:array, Ecto.Enum}, values: Flags.db_flag_keys() |> Enum.to_list())

    belongs_to(:owner, DB.Object)
    belongs_to(:parent, DB.Object)
    belongs_to(:location, DB.Object)
    belongs_to(:link, DB.Object)
    has_many(:attributes, DB.Object.Attribute)
  end

  alias ExMUSH.ObjectID, as: OID
  alias ExMUSH.World

  @spec to_world(%DB.Object{}) :: %World.Object{}
  def to_world(%DB.Object{} = object) do
    %World.Object{
      oid: OID.from_db(object.id),
      name: object.name,
      type: object.type,
      flags: MapSet.new(object.flags),
      ctime: DB.dbtime_to_wtime(object.inserted_at),
      mtime: DB.dbtime_to_wtime(object.updated_at),
      owner_oid: OID.from_db(object.owner_id),
      parent_oid: OID.from_db(object.parent_id),
      location_oid: OID.from_db(object.location_id),
      link_oid: OID.from_db(object.link_id),
      aliases:
        case object.attributes do
          [%DB.Object.Attribute{name: "ALIAS", value: v}] -> v
          [] -> ""
        end
        |> load_aliases(object.type, object.name)
    }
  end

  @spec from_world(%World.Object{}) :: keyword()
  def from_world(%World.Object{} = object) do
    [
      id: OID.to_db(object.oid),
      name: object.name,
      type: object.type,
      flags:
        object.flags
        |> MapSet.intersection(Flags.db_flag_keys())
        |> Enum.to_list(),
      ctime: DB.wtime_to_dbtime(object.ctime),
      mtime: DB.wtime_to_dbtime(object.mtime),
      owner_id: OID.to_db(object.owner_oid),
      parent_id: OID.to_db(object.parent_oid),
      location_id: OID.to_db(object.location_oid),
      link_id: OID.to_db(object.link_oid)
    ]
  end

  defp load_aliases(attr_value, type, name) when type in [:player, :exit] do
    attr_value
    |> String.downcase()
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> MapSet.new()
    |> MapSet.put(name)
  end

  defp load_aliases(_attr_value, type, name) when type in [:thing, :room] do
    name
    |> String.downcase()
    |> String.split()
    |> MapSet.new()
    |> MapSet.put(name)
  end
end
