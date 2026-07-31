defmodule ExMUSH.Context do
  import ExMUSH

  @enforce_keys [:player, :this, :caller]
  defstruct(@enforce_keys)

  alias __MODULE__

  def for_player(oid) when is_object_id(oid) do
    %Context{player: oid, this: oid, caller: oid}
  end
end
