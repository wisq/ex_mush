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

  defguardp is_object_or_oid(oo) when is_object_id(oo) or is_struct(oo, Object)
  defp to_object_id(%Object{oid: oid}), do: oid
  defp to_object_id(oid) when is_object_id(oid), do: oid

  def from_db(%DB.Object{} = obj) do
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
        oid = Map.fetch!(obj, db_key) |> OID.from_db()
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

  def to_db(%Object{} = obj) do
    base =
      Map.take(obj, @base_keys)
      |> Enum.to_list()

    flags =
      obj.flags
      |> MapSet.intersection(Flags.db_flag_keys())
      |> Enum.to_list()
      |> then(&[flags: &1])

    times =
      @time_keys
      |> Enum.map(fn {my_key, db_key} ->
        {_unix, datetime} = Map.fetch!(obj, my_key)
        {db_key, datetime}
      end)

    oids =
      @oid_keys
      |> Enum.map(fn {my_key, db_key} ->
        oid = Map.fetch!(obj, my_key) |> OID.to_db()
        {db_key, oid}
      end)

    base ++ flags ++ times ++ oids
  end

  defdelegate fetch(oid), to: ObjectDirectory

  def get(%OID{} = oid) do
    case fetch(oid) do
      {:ok, %Object{} = obj} -> obj
      :error -> raise "object #{oid} not found"
    end
  end

  def get_or_nil(~o'#-1'), do: nil
  def get_or_nil(%OID{} = oid), do: get(oid)

  # Stock PennMUSH has an exit's link as its source, and location as its destination.
  # I've chosen to reverse that to make things more logical, but it does mean
  # we need to reverse how this function works for exits.
  def home(%Object{type: :exit, location_oid: oid}), do: get(oid)
  # A room's home is its drop-to location, and is optional.
  def home(%Object{type: :room, link_oid: oid}), do: get_or_nil(oid)
  # Everything else MUST have a home.
  def home(%Object{link_oid: oid}), do: get(oid)

  def contents(%Object{oid: oid}), do: contents(oid)

  def contents(%OID{} = oid) do
    ObjectDirectory.content_oids(oid)
    |> Enum.map(&get/1)
  end

  def inventory_and_exits(obj) when is_object_or_oid(obj) do
    contents(obj)
    |> Enum.split_with(&(&1.type != :exit))
  end

  def attribute(%OID{} = oid, attr), do: ObjectServer.attribute(oid, attr)
  def attribute(%Object{oid: oid}, attr), do: ObjectServer.attribute(oid, attr)

  def tell(%OID{} = oid, iodata), do: get(oid) |> tell(iodata)

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

  def move(what, from \\ :anywhere, to)

  def move(what, :anywhere, to) when is_object_or_oid(what) and is_object_or_oid(to),
    do: ObjectDirectory.move(to_object_id(what), :anywhere, to_object_id(to))

  def move(what, from, to)
      when is_object_or_oid(what) and is_object_or_oid(from) and is_object_or_oid(to),
      do: ObjectDirectory.move(to_object_id(what), to_object_id(from), to_object_id(to))
end
