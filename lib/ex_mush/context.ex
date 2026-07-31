defmodule ExMUSH.Context do
  import ExMUSH
  alias ExMUSH.World.Object

  @enforce_keys [:player, :this, :caller]
  defstruct(@enforce_keys)

  alias __MODULE__

  def for_player(oid) when is_object_id(oid) do
    player = Object.get(oid)
    %Context{player: player, this: player, caller: player}
  end
end
