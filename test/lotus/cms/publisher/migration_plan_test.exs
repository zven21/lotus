defmodule Lotus.CMS.Publisher.MigrationPlanTest do
  use ExUnit.Case, async: true

  alias Lotus.CMS.Publisher.{DiffEngine, MigrationPlan}

  @old %{
    "meta" => %{"version" => "1.0.0", "name" => "Author", "slug" => "author"},
    "storage" => %{"table" => "cms_authors", "indexes" => []},
    "fields" => [
      %{"name" => "name", "type" => "string"}
    ],
    "relationships" => []
  }

  test "plan add/drop/alter columns" do
    new = %{
      "meta" => %{"version" => "1.1.0", "name" => "Author", "slug" => "author"},
      "storage" => %{"table" => "cms_authors", "indexes" => []},
      "fields" => [
        %{"name" => "name", "type" => "text"},
        %{"name" => "email", "type" => "string"}
      ],
      "relationships" => []
    }

    diff = DiffEngine.diff(@old, new)
    plan = MigrationPlan.generate(@old, new, diff)

    assert plan.table == "cms_authors"

    expected = [
      {:alter_column_type, :name, :text},
      {:add_column, :email, :string}
    ]

    assert Enum.sort(plan.operations) == Enum.sort(expected)
  end

  test "plan for belongs_to adds fk column and index" do
    old = @old

    new =
      put_in(@old["relationships"], [
        %{"name" => "author", "kind" => "belongs_to", "target" => %{"slug" => "user"}}
      ])

    diff = DiffEngine.diff(old, new)
    plan = MigrationPlan.generate(old, new, diff)

    assert plan.operations == [
             {:add_column, :author_id, {:references, :cms_users, :uuid, on_delete: :restrict}},
             {:add_index, [:author_id]}
           ]
  end

  test "plan for field rename and unique index add/remove" do
    old = @old

    new =
      @old
      |> put_in(["fields"], [
        %{"name" => "full_name", "type" => "string"}
      ])
      |> put_in(["ops"], %{"compat" => %{"renames" => [%{"from" => "name", "to" => "full_name"}]}})
      |> put_in(["storage", "indexes"], [
        %{"type" => "unique", "columns" => ["email"], "name" => "authors_email_unique"}
      ])

    diff1 = DiffEngine.diff(old, new)
    plan1 = MigrationPlan.generate(old, new, diff1)

    assert Enum.member?(plan1.operations, {:rename_column, :name, :full_name})
    assert Enum.member?(plan1.operations, {:create_unique_index, [:email], :authors_email_unique})

    # reverse remove unique index
    diff2 = DiffEngine.diff(new, old)
    plan2 = MigrationPlan.generate(new, old, diff2)
    assert Enum.member?(plan2.operations, {:drop_unique_index, [:email], :authors_email_unique})
  end

  test "empty diff returns no operations" do
    diff = DiffEngine.diff(@old, @old)
    plan = MigrationPlan.generate(@old, @old, diff)
    assert plan.operations == []
  end
end
