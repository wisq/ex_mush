defmodule ExMUSH.World.Object.Attribute do
  alias __MODULE__
  alias ExMUSH.DB
  alias ExMUSH.ObjectID, as: OID

  @enforce_keys [:name, :owner_id, :flags, :value]
  defstruct(@enforce_keys)

  def from_db(%DB.Object.Attribute{} = a) do
    %Attribute{
      name: a.name,
      owner_id: OID.from_db(a.owner_id),
      flags: a.flags,
      value: a.value
    }
  end
end
