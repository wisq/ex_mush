defmodule ExMUSH.World.Object do
  import ExMUSH

  alias __MODULE__
  alias __MODULE__.Flags

  alias ExMUSH.DB
  alias ExMUSH.World.{ObjectDirectory, ObjectServer}
  alias ExMUSH.ObjectID, as: OID
  alias ExMUSH.Network

  @base_keys [:name, :type]
  @time_keys [
    ctime: :inserted_at,
    mtime: :updated_at
  ]
  @oid_keys [
    oid: :id,
    owner_oid: :owner_id,
    parent_oid: :parent_id,
    location_oid: :location_id,
    link_oid: :link_id
  ]
  @derived_keys [:aliases]

  @enforce_keys [
                  @base_keys,
                  [:flags],
                  Keyword.keys(@time_keys),
                  Keyword.keys(@oid_keys),
                  @derived_keys
                ]
                |> Enum.reduce(&Kernel.++/2)
  defstruct(@enforce_keys)

  def load(%DB.Object{} = obj) do
    base =
      Map.take(obj, @base_keys)
      |> Enum.to_list()

    flags = [flags: MapSet.new(obj.flags)]

    times =
      @time_keys
      |> Enum.map(fn {my_key, db_key} ->
        datetime = Map.fetch!(obj, db_key)
        unix = datetime |> DateTime.to_unix()
        {my_key, {unix, datetime}}
      end)

    oids =
      @oid_keys
      |> Enum.map(fn {my_key, db_key} ->
        oid = Map.fetch!(obj, db_key) |> OID.load()
        {my_key, oid}
      end)

    aliases =
      case obj.attributes do
        [%DB.Object.Attribute{name: "ALIAS", value: v}] ->
          [aliases: v |> String.split(";") |> Enum.map(&String.trim/1)]

        [] ->
          [aliases: []]
      end

    struct!(Object, base ++ flags ++ times ++ oids ++ aliases)
  end

  defdelegate get(oid), to: ObjectDirectory
  defdelegate fetch(oid), to: ObjectDirectory

  [:owner, :parent, :location, :link]
  |> Enum.each(fn key ->
    defdelegate unquote(key)(oid), to: ObjectDirectory
    defdelegate unquote(:"#{key}_oid")(oid), to: ObjectDirectory
  end)

  defdelegate content_oids(oid), to: ObjectDirectory
  defdelegate contents(oid), to: ObjectDirectory

  def inventory_and_exits(%Object{oid: oid}), do: inventory_and_exits(oid)

  def inventory_and_exits(oid) when is_object_id(oid) do
    ObjectDirectory.contents(oid)
    |> Enum.split_with(&(&1.type != :exit))
  end

  def attribute(oid, attr) when is_object_id(oid), do: ObjectServer.attribute(oid, attr)
  def attribute(%Object{oid: oid}, attr), do: ObjectServer.attribute(oid, attr)

  def tell(oid, iodata) when is_object_id(oid), do: get(oid) |> tell(iodata)

  def tell(%Object{} = this, iodata) do
    if this.type == :player do
      Network.SessionRegistry.notify(this.oid, iodata)
    end
  end

  def full_name(%Object{} = this, %Object{} = player) do
    if :myopic not in player.flags and controls?(player, this) do
      [this.name, "(", to_string(this.oid), Flags.letters(this), ")"]
    else
      this.name
    end
  end

  def controls?(%Object{} = player, %Object{} = object) do
    object.owner_oid == player.oid || :wizard in player.flags
  end
end
