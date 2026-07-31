defmodule ExMUSH.Commands.Look do
  use ExMUSH.Command
  alias ExMUSH.Context
  alias ExMUSH.World.Object
  alias ExMUSH.World.Matching

  @command "look"
  @aliases ["l"]
  @switches ["outside"]
  @parser :one_arg

  defcommand look(%Context{player: player_oid}, _switches, target_name \\ "here") do
    case Matching.locate(player_oid, target_name, %Matching.Opts{location: false}) do
      {:ok, target} -> Object.get(player_oid) |> do_look(target)
      {:error, :no_match} -> Object.tell(player_oid, "I don't see that here.")
      {:error, :ambiguous_match} -> Object.tell(player_oid, "I'm not sure which one you mean.")
    end
  end

  defp do_look(player, target) do
    {inventory, exits} = Object.inventory_and_exits(target)
    inventory = inventory |> Enum.filter(&visible?(&1, target, player))
    exits = exits |> Enum.filter(&visible?(&1, target, player))

    [
      Object.full_name(target, player),
      look_description(target),
      look_inventory(target, player, inventory),
      look_exits(target, player, exits)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.intersperse("\n")
    |> then(&Object.tell(player, &1))
  end

  defp look_description(target) do
    case Object.attribute(target, "DESCRIBE") do
      %Object.Attribute{value: v} -> v
      nil -> "You see nothing special."
    end
  end

  defp look_inventory(_, _, []), do: nil

  defp look_inventory(target, player, inventory) do
    [
      case target.type do
        :player -> "Carrying:"
        :thing -> "Carrying:"
        _ -> "Contents:"
      end,
      "\n",
      inventory
      |> Enum.map(&Object.full_name(&1, player))
      |> Enum.intersperse("\n")
    ]
  end

  defp look_exits(_, _, []), do: nil

  defp look_exits(_target, _player, exits) do
    [
      "Obvious exits:",
      "\n",
      exits
      |> Enum.map(& &1.name)
      |> comma_list()
    ]
  end

  defp comma_list([a]), do: a
  defp comma_list([a, b]), do: a <> " and " <> b
  defp comma_list([_, _ | _] = list), do: oxford_comma(list)

  defp oxford_comma([a, b]), do: a <> ", and " <> b
  defp oxford_comma([head | rest]), do: head <> ", " <> oxford_comma(rest)

  # Players don't see themselves in lists.
  defp visible?(%Object{oid: p_oid}, _, %Object{oid: p_oid}), do: false

  defp visible?(%Object{type: item_type, flags: item_flags}, %Object{flags: my_flags}, _) do
    cond do
      # Disconnected players are always invisible.
      item_type == :player && :connected not in item_flags -> false
      # Light objects are always visible.
      :light in item_flags -> true
      # Dark items, or items in dark rooms, are invisible.
      :dark in item_flags -> false
      :dark in my_flags -> false
      # Everything else is visible.
      true -> true
    end
  end
end
