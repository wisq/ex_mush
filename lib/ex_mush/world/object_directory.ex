defmodule ExMUSH.World.ObjectDirectory do
  use GenServer
  import ExMUSH
  alias ExMUSH.ObjectID, as: OID
  alias ExMUSH.DB
  alias ExMUSH.World.Object

  @objects_ets __MODULE__.ETS.Objects
  @contents_ets __MODULE__.ETS.Contents
  @players_ets __MODULE__.ETS.Players

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, nil, opts)
  end

  [:owner, :parent, :location, :link]
  |> Enum.each(fn key ->
    def unquote(key)(obj_or_oid), do: unquote(:"#{key}_oid")(obj_or_oid) |> get_or_nil()
    def unquote(:"#{key}_oid")(oid) when is_object_id(oid), do: get(oid).unquote(:"#{key}_oid")
    def unquote(:"#{key}_oid")(%Object{} = obj), do: obj.unquote(:"#{key}_oid")
  end)

  def get_or_nil(~o'#-1'), do: nil
  def get_or_nil(oid), do: get(oid)

  def fetch(%OID{id: id, ctime: nil}) do
    case :ets.lookup(@objects_ets, id) do
      [{^id, %Object{} = obj}] -> {:ok, add_derived_flags(obj)}
      [] -> :error
    end
  end

  def fetch(%OID{id: id, ctime: ctime}) when is_integer(ctime) do
    case :ets.lookup(@objects_ets, id) do
      [{^id, %Object{ctime: ^ctime} = obj}] -> {:ok, add_derived_flags(obj)}
      _ -> :error
    end
  end

  defp add_derived_flags(%Object{type: :player} = player) do
    case ExMUSH.Network.SessionRegistry.connected?(player.oid) do
      true -> %Object{player | flags: [:connected, player.flags]}
      false -> player
    end
  end

  defp add_derived_flags(%Object{} = obj), do: obj

  def get(oid) when is_object_id(oid) do
    case fetch(oid) do
      {:ok, %Object{} = obj} -> obj
      :error -> raise "object #{oid} not found"
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

  def match_player(name, mode \\ :partial) when mode in [:partial, :exact] do
    case match_player_oid(name, mode) do
      {:ok, oid} -> {:ok, get(oid)}
      {:error, _} = err -> err
    end
  end

  def match_player_oid(name, mode \\ :partial) when mode in [:partial, :exact] do
    name = String.downcase(name)

    case :ets.lookup(@players_ets, name) do
      [{^name, oid}] ->
        {:ok, oid}

      [] ->
        case mode do
          :exact -> {:error, :no_match}
          :partial -> partial_match_player(name)
        end
    end
  end

  defp partial_match_player(name) do
    case :ets.next_lookup(@players_ets, name) do
      {^name <> _ = match, [{match, oid}]} ->
        # We found a partial match, but if the next ALSO matches, it's ambiguous.
        case :ets.next(@players_ets, match) do
          ^name <> _ -> {:error, :ambiguous_match}
          _ -> {:ok, oid}
        end

      {_, [_]} ->
        {:error, :no_match}

      :"$end_of_table" ->
        {:error, :no_match}
    end
  end

  @impl true
  def init(_) do
    :ets.new(@objects_ets, [:set, :protected, :named_table])
    :ets.new(@players_ets, [:ordered_set, :protected, :named_table])
    :ets.new(@contents_ets, [:bag, :protected, :named_table])

    objs = load_objects()
    index_objects(objs)
    index_players(objs)
    index_contents(objs)

    {:ok, nil}
  end

  defp load_objects do
    DB.Repo.get_objects_for_directory()
    |> Enum.map(&Object.load/1)
  end

  defp index_objects(objs) do
    objs
    |> Enum.map(fn obj -> {obj.oid.id, obj} end)
    |> then(&:ets.insert(@objects_ets, &1))
  end

  defp index_players(objs) do
    objs
    |> Enum.filter(fn obj -> obj.type == :player end)
    |> Enum.flat_map(fn obj ->
      [obj.name | obj.aliases]
      |> Enum.uniq()
      |> Enum.map(fn n -> {String.downcase(n), obj.oid} end)
    end)
    |> then(&:ets.insert(@players_ets, &1))
  end

  defp index_contents(objs) do
    objs
    |> Enum.map(fn obj -> {obj.location_oid.id, obj.oid} end)
    |> Enum.reject(fn {loc_id, _} -> loc_id < 0 end)
    |> then(&:ets.insert(@contents_ets, &1))
  end
end
