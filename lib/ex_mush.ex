defmodule ExMUSH do
  defguard is_object_id(oid) when is_struct(oid, ExMUSH.ObjectID)

  defmacro sigil_o({:<<>>, _, ["#" <> idstr]}, _modifiers) do
    case String.split(idstr, ":") do
      [id_str] ->
        id = String.to_integer(id_str)
        macro_struct(id, nil)

      [id_str, ctime_str] ->
        id = String.to_integer(id_str)
        ctime = String.to_integer(ctime_str)
        macro_struct(id, ctime)
    end
  end

  # Helper to inject the struct directly into the AST at compile time
  defp macro_struct(id, ctime) do
    {:%, [],
     [{:__aliases__, [alias: false], [:"ExMUSH.ObjectID"]}, {:%{}, [], [id: id, ctime: ctime]}]}
  end
end
