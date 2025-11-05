defmodule Lotus.Repo.Migrations.CreateContents do
  use Ecto.Migration

  def change do
    # content_types 表
    create table(:content_types, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :slug, :string, size: 100, null: false
      add :name, :string, size: 100, null: false
      add :description, :text
      add :options, :jsonb, default: fragment("'{}'::jsonb")
      timestamps type: :utc_datetime_usec
    end

    create unique_index(:content_types, [:slug])
    create index(:content_types, [:name])

    create table(:content_fields, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :content_type_id, references(:content_types, type: :uuid, on_delete: :delete_all),
        null: false

      add :name, :string, size: 100, null: false
      add :kind, :string, size: 50, null: false
      add :required, :boolean, default: false
      add :unique, :boolean, default: false
      add :default, :text
      add :order, :integer, default: 0
      add :options, :jsonb, default: fragment("'{}'::jsonb")
      timestamps type: :utc_datetime_usec
    end

    create unique_index(:content_fields, [:content_type_id, :name],
             name: :content_fields_content_type_id_name_index
           )

    create index(:content_fields, [:content_type_id])

    # content_relations
    create table(:content_relations, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :content_type_id, references(:content_types, type: :uuid, on_delete: :delete_all),
        null: false

      add :name, :string, size: 100, null: false
      add :type, :string, size: 50, null: false
      # type: 'manyToOne', 'oneToMany', 'manyToMany', 'oneToOne'

      add :target, :string, size: 100, null: false
      add :foreign_key, :string, size: 100
      add :target_field, :string, size: 100
      add :on_delete, :string, size: 20, default: "restrict"
      add :through, :string, size: 200
      add :options, :jsonb, default: fragment("'{}'::jsonb")

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:content_relations, [:content_type_id, :name],
             name: :content_relations_content_type_id_name_index
           )

    create index(:content_relations, [:content_type_id])
    create index(:content_relations, [:target])
  end
end
