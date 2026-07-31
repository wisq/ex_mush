defmodule ExMUSH.DB.Object do
  use Ecto.Schema
  alias __MODULE__
  alias __MODULE__.Attribute
  alias ExMUSH.World.Object.Flags

  schema "objects" do
    timestamps(type: :utc_datetime_usec)

    field(:name, :string)
    field(:type, Ecto.Enum, values: [:room, :thing, :exit, :player, :garbage])
    field(:flags, {:array, Ecto.Enum}, values: Flags.db_flag_keys() |> Enum.to_list())

    belongs_to(:owner, Object)
    belongs_to(:parent, Object)
    belongs_to(:location, Object)
    belongs_to(:link, Object)
    has_many(:attributes, Attribute)
  end
end
