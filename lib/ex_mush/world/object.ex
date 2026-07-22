defmodule ExMUSH.World.Object do
  use GenServer
  alias ExMUSH.DB
  alias ExMUSH.World.{ObjectDirectory, ObjectSupervisor, ObjectRegistry}

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

  defdelegate owner_id(obj_id), to: ObjectDirectory
  defdelegate parent_id(obj_id), to: ObjectDirectory
  defdelegate location_id(obj_id), to: ObjectDirectory
  defdelegate link_id(obj_id), to: ObjectDirectory
  defdelegate contents(obj_id), to: ObjectDirectory

  def attribute(obj_id, key) do
    {:ok, _pid, attrs} = ObjectSupervisor.ensure_started(obj_id)

    case :ets.lookup(attrs, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  defmodule State do
    @enforce_keys [:id, :attrs_table]
    defstruct(@enforce_keys)
  end

  @impl true
  def init(id) do
    attrs = :ets.new(:attributes, [:ordered_set, :protected])

    with {:ok, obj} <- DB.fetch_object(id),
         load_attributes(attrs, obj.attributes),
         {:ok, _} <- ObjectRegistry.register(id, attrs) do
      {:ok, %State{id: id, attrs_table: attrs}}
    end
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
end
