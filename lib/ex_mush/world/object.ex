defmodule ExMUSH.World.Object do
  alias __MODULE__
  alias ExMUSH.DB
  alias ExMUSH.World.{ObjectDirectory, ObjectServer}
  alias ExMUSH.ObjectID, as: OID

  @base_keys [:name, :type, :flags]
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

    times =
      @time_keys
      |> Enum.map(fn {my_key, db_key} ->
        time = Map.fetch!(obj, db_key) |> DateTime.to_unix()
        {my_key, time}
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

    struct!(Object, base ++ times ++ oids ++ aliases)
  end

  defdelegate get(oid), to: ObjectDirectory

  [:owner, :parent, :location, :link]
  |> Enum.each(fn key ->
    defdelegate unquote(key)(oid), to: ObjectDirectory
    defdelegate unquote(:"#{key}_oid")(oid), to: ObjectDirectory
  end)

  defdelegate content_oids(oid), to: ObjectDirectory
  defdelegate contents(oid), to: ObjectDirectory

  defdelegate attribute(oid, attr_name), to: ObjectServer
end
