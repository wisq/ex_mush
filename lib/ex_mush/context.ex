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

  def update(
        %Context{player: old_player, this: old_this, caller: old_caller},
        %Object{oid: oid} = new_object
      ) do
    %Context{
      player:
        case old_player do
          %Object{oid: ^oid} -> new_object
          other -> other
        end,
      this:
        case old_this do
          %Object{oid: ^oid} -> new_object
          other -> other
        end,
      caller:
        case old_caller do
          %Object{oid: ^oid} -> new_object
          other -> other
        end
    }
  end
end
