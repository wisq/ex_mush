defmodule ExMUSH.Context do
  import ExMUSH

  @enforce_keys [:enactor, :executor, :caller]
  defstruct(@enforce_keys)

  alias __MODULE__

  def for_player(oid) when is_object_id(oid) do
    %Context{enactor: oid, executor: oid, caller: oid}
  end
end
