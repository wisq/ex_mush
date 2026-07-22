defmodule ExMUSH.World.ObjectDirectory do
  use GenServer
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
    def unquote(key)(obj_id), do: unquote(:"#{key}_id")(obj_id) |> get()
    def unquote(:"#{key}_id")(obj_id), do: get(obj_id).unquote(:"#{key}_id")
  end)

  def get(nil), do: nil

  def get(obj_id) do
    case :ets.lookup(@objects_ets, obj_id) do
      [{^obj_id, obj}] -> obj
      [] -> raise "object #{obj_id} not found"
    end
  end

  def contents(obj_id) do
    :ets.lookup(@contents_ets, obj_id)
    |> Enum.map(fn {^obj_id, c_id} -> c_id end)
  end

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
    |> Enum.map(fn o -> {o.id, o} end)
    |> then(&:ets.insert(@objects_ets, &1))
  end

  defp index_contents(objs) do
    objs
    |> Enum.map(fn o -> {o.location_id, o.id} end)
    |> Enum.reject(fn {loc, _} -> is_nil(loc) end)
    |> then(&:ets.insert(@contents_ets, &1))
  end
end
