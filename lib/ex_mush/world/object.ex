defmodule ExMUSH.World.Object do
  use GenServer
  alias ExMUSH.DB

  defmodule Attribute do
    @enforce_keys [:name, :owner_id, :flags, :value]
    defstruct(
      Enum.map(@enforce_keys, fn k -> {k, nil} end)
      |> Kernel.++(dirty: false)
    )
  end

  def start_link(opts) do
    {obj_id, opts} = Keyword.pop!(opts, :object_id)
    name = process_name(obj_id)
    opts = Keyword.put_new(opts, :name, name)
    GenServer.start_link(__MODULE__, {name, obj_id}, opts)
  end

  def owner_id(obj_id), do: meta_table(obj_id) |> :ets.lookup(:owner_id)
  def parent_id(obj_id), do: meta_table(obj_id) |> :ets.lookup(:parent_id)

  defmodule State do
    @enforce_keys [:id, :meta_table, :attrs_table]
    defstruct(@enforce_keys)
  end

  @impl true
  def init({name, id}) do
    meta = meta_table(name) |> :ets.new([:set, :protected, :named_table])
    attrs = attrs_table(name) |> :ets.new([:ordered_set, :protected, :named_table])

    case DB.get_object(id) do
      %DB.Object{} = obj ->
        load_metadata(meta, obj)
        load_attributes(attrs, obj.attributes)
        {:ok, %State{id: id, meta_table: meta, attrs_table: attrs}}

      nil ->
        {:error, :object_not_found}
    end
  end

  defp load_metadata(table, %DB.Object{} = obj) do
    Map.from_struct(obj)
    |> Enum.to_list()
    |> Keyword.take([:owner_id, :parent_id])
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

  defp process_name(obj_id), do: __MODULE__ |> Module.concat("Obj#{obj_id}")

  defp meta_table(name) when is_atom(name), do: name |> Module.concat("Metadata")
  defp meta_table(obj_id) when is_integer(obj_id), do: process_name(obj_id) |> meta_table()

  defp attrs_table(name) when is_atom(name), do: name |> Module.concat("Attributes")
  defp attrs_table(obj_id) when is_integer(obj_id), do: process_name(obj_id) |> attrs_table()
end
