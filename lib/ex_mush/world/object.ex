defmodule ExMUSH.World.Object do
  use GenServer
  alias ExMUSH.DB
  alias ExMUSH.World.{ObjectSupervisor, ObjectRegistry}

  defmodule Attribute do
    @enforce_keys [:name, :owner_id, :flags, :value]
    defstruct(
      Enum.map(@enforce_keys, fn k -> {k, nil} end)
      |> Kernel.++(dirty: false)
    )
  end

  def child_spec(obj_id) do
    super(object_id: obj_id)
    |> Map.put(:restart, :temporary)
  end

  def start_link(opts) do
    {obj_id, opts} = Keyword.pop!(opts, :object_id)
    GenServer.start_link(__MODULE__, obj_id, opts)
  end

  def owner_id(obj_id), do: get_metadata(obj_id, :owner_id)
  def parent_id(obj_id), do: get_metadata(obj_id, :parent_id)
  def link_id(obj_id), do: get_metadata(obj_id, :link_id)

  defmodule State do
    @enforce_keys [:id, :meta_table, :attrs_table]
    defstruct(@enforce_keys)
  end

  @impl true
  def init(id) do
    meta = :ets.new(:metadata, [:set, :protected])
    attrs = :ets.new(:attributes, [:ordered_set, :protected])

    with {:ok, obj} <- DB.fetch_object(id),
         load_metadata(meta, obj),
         load_attributes(attrs, obj.attributes),
         {:ok, _} <- ObjectRegistry.register(id, {meta, attrs}) do
      {:ok, %State{id: id, meta_table: meta, attrs_table: attrs}}
    end
  end

  defp load_metadata(table, %DB.Object{} = obj) do
    Map.from_struct(obj)
    |> Enum.to_list()
    |> Keyword.take([:owner_id, :parent_id, :link_id])
    |> then(&:ets.insert(table, &1))
  end

  defp load_attributes(table, attrs) do
    attrs
    |> Enum.map(fn a ->
      {a.name,
       %Attribute{
         name: a.name,
         owner_id: a.owner_id,
         flags: a.flags,
         value: a.value
       }}
    end)
    |> then(&:ets.insert(table, &1))
  end

  defp get_metadata(obj_id, key) do
    {_pid, {meta, _attrs}} = ObjectSupervisor.ensure_started(obj_id)
    [{^key, value}] = :ets.lookup(meta, key)
    value
  end

  def attribute(obj_id, key) do
    {_pid, {_meta, attrs}} = ObjectSupervisor.ensure_started(obj_id)

    case :ets.lookup(attrs, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end
end
