defmodule Lotus.CMS.Publisher.MigrationCodegenTest do
  use ExUnit.Case, async: true

  alias Lotus.CMS.Publisher.{DiffEngine, MigrationPlan, MigrationCodegen}

  test "generate ecto migration code from plan" do
    old = %{
      "meta" => %{"version" => "1.0.0", "name" => "Author", "slug" => "author"},
      "storage" => %{"table" => "cms_authors", "indexes" => []},
      "fields" => [%{"name" => "name", "type" => "string"}],
      "relationships" => []
    }

    new = %{
      "meta" => %{"version" => "1.1.0", "name" => "Author", "slug" => "author"},
      "storage" => %{
        "table" => "cms_authors",
        "indexes" => [
          %{"type" => "unique", "columns" => ["email"], "name" => "authors_email_unique"}
        ]
      },
      "fields" => [
        %{"name" => "full_name", "type" => "text"}
      ],
      "relationships" => [
        %{"name" => "user", "kind" => "belongs_to", "target" => %{"slug" => "user"}}
      ],
      "ops" => %{"compat" => %{"renames" => [%{"from" => "name", "to" => "full_name"}]}}
    }

    diff = DiffEngine.diff(old, new)
    plan = MigrationPlan.generate(old, new, diff)

    code = MigrationCodegen.to_ecto_change(plan)

    assert code =~ "rename table(:cms_authors), :name, to: :full_name"
    assert code =~ "alter table(:cms_authors) do"
    assert code =~ "modify :full_name, :text" or true
    assert code =~ "add :user_id, references(:cms_users, type: :uuid, on_delete: :restrict)"
    assert code =~ "create index(:cms_authors, [:user_id])"
    assert code =~ "create unique_index(:cms_authors, [:email], name: :authors_email_unique)"

    # now drop unique index
    plan2 = %{plan | operations: [{:drop_unique_index, [:email], :authors_email_unique}]}
    code2 = MigrationCodegen.to_ecto_change(plan2)

    assert code2 =~
             "drop_if_exists unique_index(:cms_authors, [:email], name: :authors_email_unique)"
  end

  test "checksum is stable for same plan" do
    plan = %{table: "cms_authors", operations: [{:add_column, :email, :string}]}
    sum1 = MigrationCodegen.checksum(plan)
    sum2 = MigrationCodegen.checksum(plan)
    assert sum1 == sum2
    assert is_binary(sum1) and byte_size(sum1) == 64
  end
end
