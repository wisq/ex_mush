defmodule ExMUSH do
  alias ExMUSH.ObjectID

  defguard is_object_id(oid) when is_struct(oid, ObjectID)

  defmacro sigil_o({:<<>>, _, [idstr]}, _modifiers) do
    {:ok, oid} = ObjectID.parse(idstr)
    macro_struct(oid.id, oid.ctime)
  end

  # Helper to inject the struct directly into the AST at compile time
  defp macro_struct(id, ctime) do
    {:%, [],
     [{:__aliases__, [alias: false], [:"ExMUSH.ObjectID"]}, {:%{}, [], [id: id, ctime: ctime]}]}
  end
end
