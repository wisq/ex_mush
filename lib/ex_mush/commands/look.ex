defmodule ExMUSH.Commands.Look do
  use ExMUSH.Command
  alias ExMUSH.Context
  alias ExMUSH.World.Object
  alias ExMUSH.World.Matching

  @command "look"
  @aliases ["l"]
  @switches ["outside"]
  @parser :one_arg

  defcommand look(%Context{executor: player_oid}, _switches, target_name \\ "here") do
    case Matching.locate(player_oid, target_name, %Matching.Opts{location: false}) do
      {:ok, target} -> Object.get(player_oid) |> do_look(target)
      {:error, :no_match} -> Object.tell(player_oid, "I don't see that here.")
      {:error, :ambiguous_match} -> Object.tell(player_oid, "I'm not sure which one you mean.")
    end
  end

  defp do_look(player, this) do
    {inventory, exits} = Object.inventory_and_exits(this)

    [
      Object.full_name(this, player),
      look_description(this),
      look_inventory(this, player, inventory),
      look_exits(this, player, exits)
    ]
    |> Enum.intersperse("\n")
    |> then(&Object.tell(player, &1))
  end

  defp look_description(this) do
    case Object.attribute(this, "DESCRIBE") do
      %Object.Attribute{value: v} -> v
      nil -> "You see nothing special."
    end
  end

  defp look_inventory(_, _, []), do: []

  defp look_inventory(%Object{type: type}, player, inventory) do
    [
      case type do
        :player -> "Carrying:"
        :thing -> "Carrying:"
        _ -> "Contents:"
      end,
      "\n",
      inventory
      |> List.delete(player)
      |> Enum.map(&Object.full_name(&1, player))
      |> Enum.intersperse("\n")
    ]
  end

  defp look_exits(_, _, []), do: []

  defp look_exits(_, _, exits) do
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
end
