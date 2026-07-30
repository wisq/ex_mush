defmodule ExMUSH.DB.Repo.Migrations.CreateObjectAttributes do
  use Ecto.Migration

  def change do
    create table("object_attributes") do
      timestamps(type: :utc_datetime_usec)

      add :object_id, references("objects"), null: false
      add :name, :string, null: false
      add :value, :string, size: 8192, null: false

      add :owner_id, references("objects"), null: false
      add :flags, {:array, :string}, null: false
    end

    create unique_index("object_attributes", [:object_id, :name])

    create constraint("object_attributes", :object_attributes_name_uppercase,
      check: "name = UPPER(name)")
  end
end
