defmodule ExMUSH.World.Matching do
  import ExMUSH

  alias ExMUSH.ObjectID
  alias ExMUSH.World.Object
  alias ExMUSH.World.ObjectDirectory

  defmodule Opts do
    defstruct(
      # Preferred object type, or nil for no type
      preferred_type: nil,
      # Require exact matches only
      exact_match: false,
      # Allow ambiguous matches, always return one of them
      allow_ambiguous: false,
      # Match basic strings like "me" and "here"
      me: true,
      here: true,
      # Match absolute objects like "#123"
      oid: true,
      # Match players in "*player" and just "player" formats (name/aliases)
      star_players: true,
      always_players: false,
      # Match origin's location, inventory, or exit list
      location: true,
      inventory: true,
      exits: true,
      # Match objects or exits in same room as origin
      nearby_objects: true,
      nearby_exits: true
    )
  end

  def locate(origin_oid, text, opts \\ %Opts{})

  def locate(origin_oid, "me", %Opts{me: true}) when is_object_id(origin_oid),
    do: {:ok, Object.get(origin_oid)}

  def locate(origin_oid, "here", %Opts{me: true}) when is_object_id(origin_oid),
    do: Object.location(origin_oid) |> handle_get()

  def locate(_, "*" <> pname, %Opts{star_players: true, exact_match: false}),
    do: ObjectDirectory.match_player(pname, :partial)

  def locate(_, "*" <> pname, %Opts{star_players: true, exact_match: true}),
    do: ObjectDirectory.match_player(pname, :exact)

  def locate(_, "#" <> _ = idstr, %Opts{oid: true}) do
    with {:ok, oid} <- ObjectID.parse(idstr),
         {:ok, %Object{} = obj} <- Object.fetch(oid) do
      {:ok, obj}
    else
      _ -> {:error, :no_match}
    end
  end

  def locate(origin_oid, text, %Opts{always_players: true} = opts) do
    case ObjectDirectory.match_player(text, :exact) do
      {:ok, oid} -> {:ok, oid}
      {:error, :no_match} -> locate(origin_oid, text, %Opts{opts | always_players: false})
    end
  end

  def locate(origin_oid, text, %Opts{} = opts) when is_object_id(origin_oid) do
    origin = ObjectDirectory.get(origin_oid)
    {inventory, exits} = maybe_get_contents(origin_oid, opts)
    {nearby_objects, nearby_exits} = maybe_get_nearby(origin.location_oid, opts)

    [
      case opts.location do
        true -> [ObjectDirectory.get_or_nil(origin.location_oid)]
        false -> []
      end,
      case opts.inventory do
        true -> inventory
        false -> []
      end,
      case opts.exits do
        true -> exits
        false -> []
      end,
      case opts.nearby_objects do
        true -> nearby_objects
        false -> []
      end,
      case opts.nearby_exits do
        true -> nearby_exits
        false -> []
      end
    ]
    |> Enum.reduce(&Kernel.++/2)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(fn %Object{oid: oid} -> oid end)
    |> search_preferred_first(text, opts)
  end

  defp search_preferred_first(objects, text, %Opts{preferred_type: nil} = opts) do
    objects |> search_objects(text, opts)
  end

  defp search_preferred_first(objects, text, %Opts{preferred_type: want_type} = opts) do
    {preferred, rest} =
      objects |> Enum.split_with(fn %Object{type: type} -> type == want_type end)

    case search_objects(preferred, text, opts) do
      {:error, :no_match} -> search_objects(rest, text, opts)
      other -> other
    end
  end

  defp search_objects(objects, text, %Opts{exact_match: true} = opts),
    do: search_exact(objects, text, opts)

  defp search_objects(objects, text, %Opts{exact_match: false} = opts) do
    case search_exact(objects, text, opts) do
      {:error, :no_match} -> search_fuzzy(objects, text, opts)
      other -> other
    end
  end

  defp search_exact(objects, text, opts) do
    objects
    |> Enum.filter(fn %Object{} = obj ->
      text in all_names(obj, :exact)
    end)
    |> then(fn
      [] -> {:error, :no_match}
      [%Object{} = obj] -> {:ok, obj}
      [_, _ | _] = list -> maybe_ambiguous(list, opts)
    end)
  end

  defp search_fuzzy(objects, text, opts) do
    objects
    |> Enum.filter(fn %Object{} = obj ->
      all_names(obj, :fuzzy)
      |> Enum.any?(&String.starts_with?(&1, text))
    end)
    |> then(fn
      [] -> {:error, :no_match}
      [%Object{} = obj] -> {:ok, obj}
      [_, _ | _] = list -> maybe_ambiguous(list, opts)
    end)
  end

  defp maybe_get_contents(_, %Opts{inventory: false, exits: false}), do: {[], []}
  defp maybe_get_contents(oid, %Opts{}), do: Object.inventory_and_exits(oid)

  defp maybe_get_nearby(_, %Opts{nearby_objects: false, nearby_exits: false}), do: {[], []}
  defp maybe_get_nearby(location_oid, %Opts{}), do: Object.inventory_and_exits(location_oid)

  defp all_names(%Object{type: type, name: name, aliases: aliases}, _)
       when type in [:player, :exit], do: [name | aliases] |> Enum.map(&String.downcase/1)

  defp all_names(%Object{type: :thing, name: name}, :fuzzy) do
    dcname = String.downcase(name)
    [dcname | String.split(dcname)]
  end

  defp all_names(%Object{name: name}, _), do: [String.downcase(name)]

  defp maybe_ambiguous([head | _], %Opts{allow_ambiguous: true}), do: {:ok, head}
  defp maybe_ambiguous(_, %Opts{allow_ambiguous: false}), do: {:error, :ambiguous_match}

  defp handle_get(%Object{} = obj), do: {:ok, obj}
  defp handle_get(nil), do: {:error, :no_match}
end
