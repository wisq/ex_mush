defmodule ExMUSH.DB.Repo.Migrations.CreateObjects do
  use Ecto.Migration

  def change do
    create table("objects") do
      timestamps(type: :utc_datetime_usec)

      add :name, :string, null: false
      add :type, :string, null: false
      add :flags, {:array, :string}, null: false

      add :owner_id, references("objects"), null: false
      add :parent_id, references("objects"), null: true
      add :location_id, references("objects"), null: true
      add :link_id, references("objects"), null: false
    end

    # Rooms MUST NOT have a location.
    # Exits MAY have a location (i.e. a destination — their source is their link_id).
    # Everything else MUST have a location.
    create constraint("objects", :objects_location_optional, 
      check: "((location_id IS NULL) = (type = 'room')) OR (type = 'exit')")
  end
end
