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
      [{^id, %Object{ctime: {^ctime, _datetime}} = obj}] -> {:ok, add_derived_flags(obj)}
      _ -> :error
    end
  end

  defp add_derived_flags(%Object{type: :player} = player) do
    case ExMUSH.Network.SessionRegistry.connected?(player.oid) do
      true -> %Object{player | flags: MapSet.put(player.flags, :connected)}
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

  def move(oid, from \\ :anywhere, to)
      when is_object_id(oid) and
             (is_object_id(from) or from == :anywhere) and
             is_object_id(to) do
    GenServer.call(__MODULE__, {:move, oid, from, to})
  end

  @impl true
  def init(_) do
    ExMUSH.Network.SessionRegistry.broadcast("GAME: World has crashed, reloading ...")

    :ets.new(@objects_ets, [:set, :protected, :named_table])
    :ets.new(@players_ets, [:ordered_set, :protected, :named_table])
    :ets.new(@contents_ets, [:bag, :protected, :named_table])

    objs = load_objects()
    index_objects(objs)
    index_players(objs)
    index_contents(objs)

    ExMUSH.Network.SessionRegistry.broadcast(
      "GAME: World reloaded from database.  Check recent changes and redo if needed."
    )

    {:ok, nil}
  end

  @impl true
  def handle_call({:move, oid, from, to}, _, state)
      when is_object_id(oid) and
             (is_object_id(from) or from == :anywhere) and
             is_object_id(to) do
    with {:ok, %Object{} = object} <- fetch(oid) do
      cond do
        object.type == :room -> {:error, :cannot_move_room}
        object.location_oid == to -> {:ok, object}
        from != :anywhere && object.location_oid != from -> {:error, :object_moved}
        true -> do_update(object, location_oid: to)
      end
    end
    |> then(fn
      {:ok, _} = rval -> {:reply, rval, state}
      {:error, _} = rval -> {:reply, rval, state}
    end)
  end

  defp do_update(%Object{} = old, attrs) when is_list(attrs) do
    try do
      %Object{} = new = struct!(old, attrs)

      if new.oid != old.oid || new.aliases != old.aliases do
        {:error, :illegal_modification}
      else
        new = %Object{new | mtime: now()}
        :ets.insert(@objects_ets, [{new.oid.id, new}])
        {:ok, new}
      end
    rescue
      e in KeyError -> {:error, Exception.message(e)}
    end
  end

  defp now do
    datetime = DateTime.utc_now()
    unix = datetime |> DateTime.to_unix()
    {unix, datetime}
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
