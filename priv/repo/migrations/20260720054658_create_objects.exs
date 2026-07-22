defmodule ExMUSH.DB.Repo.Migrations.CreateObjects do
  use Ecto.Migration

  def change do
    create table("objects") do
      timestamps(type: :utc_datetime_usec)

      add :name, :string, null: false
      add :type, :string, null: false
      add :flags, {:array, :string}, null: false

      add :owner_id, references("objects"), null: false
      add :parent_id, references("objects")
      add :location_id, references("objects")
      add :link_id, references("objects")
    end

    # Rooms MUST NOT have a location.
    # Everything else MUST have a location.
    create constraint("objects", :objects_location_optional, 
      check: "(location_id IS NULL) = (type = 'room')")

    # Players and thinks MUST have a link (home).
    # Rooms MAY have a link (dropto).
    # Exits MAY have a link (destination).
    create constraint("objects", :objects_link_optional,
      check: "link_id IS NOT NULL OR type IN ('room', 'exit')")
  end
end
