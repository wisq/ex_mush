defmodule ExMUSH.World.Object do
  import ExMUSH

  alias __MODULE__
  alias __MODULE__.Flags

  alias ExMUSH.World.{ObjectDirectory, ObjectServer}
  alias ExMUSH.ObjectID, as: OID
  alias ExMUSH.Network

  @enforce_keys [
    :name,
    :type,
    :flags,
    :ctime,
    :mtime,
    :oid,
    :owner_oid,
    :parent_oid,
    :location_oid,
    :link_oid,
    :aliases
  ]
  defstruct(@enforce_keys)

  defguardp is_object_or_oid(oo) when is_object_id(oo) or is_struct(oo, Object)
  defp to_object_id(%Object{oid: oid}), do: oid
  defp to_object_id(oid) when is_object_id(oid), do: oid

  defdelegate fetch(oid), to: ObjectDirectory
  defdelegate exists?(oid), to: ObjectDirectory

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

  def announce(%OID{} = oid, iodata), do: get(oid) |> announce(iodata)

  def announce(%Object{oid: this_oid, location_oid: loc_oid}, iodata) do
    get(loc_oid)
    |> contents()
    |> Enum.reject(&(&1.oid == this_oid))
    |> Enum.map(&tell(&1, iodata))
  end

  def announce_all(%OID{} = oid, iodata), do: get(oid) |> announce(iodata)

  def announce_all(%Object{location_oid: loc_oid}, iodata) do
    get(loc_oid)
    |> contents()
    |> Enum.map(&tell(&1, iodata))
  end

  def full_name(%Object{} = this, %Object{} = player) do
    cond do
      :myopic in player.flags -> :short
      :link_ok in this.flags -> :full
      :jump_ok in this.flags -> :full
      controls?(player, this) -> :full
      true -> :short
    end
    |> then(fn
      :full -> [this.name, "(", to_string(this.oid), Flags.letters(this), ")"]
      :short -> this.name
    end)
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
