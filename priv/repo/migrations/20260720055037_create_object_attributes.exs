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
  end
end
