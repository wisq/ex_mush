defmodule ExMUSH.World.Object.Attribute do
  @enforce_keys [:name, :owner_oid, :flags, :value]
  defstruct(@enforce_keys)
end
