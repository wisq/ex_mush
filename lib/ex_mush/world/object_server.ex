defmodule ExMUSH.World.ObjectServer do
  use GenServer
  import ExMUSH
  alias ExMUSH.DB
  alias ExMUSH.World.{ObjectDirectory, ObjectSupervisor, ObjectRegistry}
  alias ExMUSH.World.Object.Attribute

  def child_spec(oid) do
    super(object_id: oid)
    |> Map.put(:restart, :temporary)
  end

  def start_link(opts) do
    {oid, opts} = Keyword.pop!(opts, :object_id)
    GenServer.start_link(__MODULE__, oid, opts)
  end

  def attribute(oid, key) when is_object_id(oid) and is_binary(key) do
    ObjectDirectory.ensure_exists(oid)
    {:ok, _pid, attrs} = ObjectSupervisor.ensure_started(oid.id)

    case :ets.lookup(attrs, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  defmodule State do
    @enforce_keys [:attrs_table]
    defstruct(@enforce_keys)
  end

  @impl true
  def init(object_id) do
    attrs = load_attributes(object_id)

    with {:ok, _} <- ObjectRegistry.register(object_id, attrs) do
      {:ok, %State{attrs_table: attrs}}
    end
  end

  defp load_attributes(object_id) do
    attrs =
      DB.Repo.all_by(DB.Object.Attribute, object_id: object_id)
      |> Enum.map(&Attribute.load/1)
      |> Enum.map(fn a -> {a.name, a} end)

    ets = :ets.new(:attributes, [:ordered_set, :protected])
    :ets.insert(ets, attrs)
    ets
  end
end
