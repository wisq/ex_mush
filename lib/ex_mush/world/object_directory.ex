defmodule ExMUSH.World.ObjectDirectory do
  use GenServer
  import ExMUSH
  alias ExMUSH.ObjectID, as: OID
  alias ExMUSH.DB
  alias ExMUSH.World

  @objects_ets __MODULE__.ETS.Objects
  @contents_ets __MODULE__.ETS.Contents

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, nil, opts)
  end

  [:owner, :parent, :location, :link]
  |> Enum.each(fn key ->
    def unquote(key)(obj_id), do: unquote(:"#{key}_oid")(obj_id) |> get_or_nil()
    def unquote(:"#{key}_oid")(obj_id), do: get(obj_id).unquote(:"#{key}_oid")
  end)

  def get_or_nil(~o'#-1'), do: nil
  def get_or_nil(oid), do: get(oid)

  def get(%OID{id: id, ctime: nil} = oid) do
    case :ets.lookup(@objects_ets, oid.id) do
      [{^id, %World.Object{} = obj}] -> obj
      [] -> raise "object #{oid} not found"
    end
  end

  def get(%OID{id: id, ctime: ctime} = oid) when is_integer(ctime) do
    case :ets.lookup(@objects_ets, oid.id) do
      [{^id, %World.Object{ctime: ^ctime} = obj}] -> obj
      _ -> raise "object #{oid} not found"
    end
  end

  # Without a ctime, we can use the faster `:ets.member/2` call.
  def exists?(%OID{id: id, ctime: nil}), do: :ets.member(@objects_ets, id)
  def exists?(%OID{ctime: ctime} = oid), do: get(oid).ctime == ctime

  def ensure_exists(oid) when is_object_id(oid) do
    unless exists?(oid), do: raise("object #{oid} not found")
  end

  def content_oids(%OID{id: id} = oid) do
    ensure_exists(oid)

    :ets.lookup(@contents_ets, id)
    |> Enum.map(fn {_, c_id} -> c_id end)
  end

  def contents(oid) when is_object_id(oid), do: content_oids(oid) |> Enum.map(&get/1)

  @impl true
  def init(_) do
    :ets.new(@objects_ets, [:set, :protected, :named_table])
    :ets.new(@contents_ets, [:bag, :protected, :named_table])

    objs = load_objects()
    index_objects(objs)
    index_contents(objs)

    {:ok, nil}
  end

  defp load_objects, do: DB.Repo.all(DB.Object) |> Enum.map(&World.Object.load/1)

  defp index_objects(objs) do
    objs
    |> Enum.map(fn o -> {o.oid.id, o} end)
    |> then(&:ets.insert(@objects_ets, &1))
  end

  defp index_contents(objs) do
    objs
    |> Enum.map(fn o -> {o.location_oid.id, o.oid} end)
    |> Enum.reject(fn {loc_id, _} -> loc_id < 0 end)
    |> then(&:ets.insert(@contents_ets, &1))
  end
end
