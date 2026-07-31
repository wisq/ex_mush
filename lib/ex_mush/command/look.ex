defmodule ExMUSH.Command.Look do
  use ExMUSH.Command
  alias ExMUSH.Context
  alias ExMUSH.World.Object
  alias ExMUSH.World.Matching

  @command "look"
  @aliases ["l"]
  @switches ["outside"]
  @parser :one_arg

  defcommand look(%Context{executor: this}, _switches, target \\ "here") do
    case Matching.locate(this, target, %Matching.Opts{location: false}) do
      {:ok, oid} -> do_look(this, oid)
      {:error, :no_match} -> Object.tell(this, "I don't see that here.")
      {:error, :ambiguous_match} -> Object.tell(this, "I'm not sure which one you mean.")
    end
  end

  defp do_look(this, target) do
    {inventory, exits} = Object.inventory_and_exits(target)

    [
      name_and_id(target),
      look_description(target),
      look_inventory(target, inventory),
      look_exits(target, exits)
    ]
    |> Enum.intersperse("\n")
    |> then(&Object.tell(this, &1))
  end

  # FIXME:
  #  - add flags
  #  - determine if ID/flags should be shown based on control / MYOPIC flag
  #  - (eventually) ANSI
  defp name_and_id(target), do: "#{target.name}(#{target.oid})"

  defp look_description(target) do
    case Object.attribute(target, "DESCRIBE") do
      %Object.Attribute{value: v} -> v
      nil -> "You see nothing special."
    end
  end

  defp look_inventory(_, []), do: []

  defp look_inventory(%Object{type: type}, inventory) do
    [
      case type do
        :player -> "Carrying:"
        :thing -> "Carrying:"
        _ -> "Contents:"
      end,
      "\n",
      inventory
      |> Enum.map(&name_and_id/1)
      |> Enum.intersperse("\n")
    ]
  end

  defp look_exits(_, []), do: []

  defp look_exits(_, exits) do
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
