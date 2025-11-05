defmodule Lotus.CMS.Publisher.DiffEngineTest do
  use ExUnit.Case, async: true

  alias Lotus.CMS.Publisher.DiffEngine

  @base_old %{
    "meta" => %{"version" => "1.0.0", "name" => "Author", "slug" => "author"},
    "storage" => %{"table" => "cms_authors", "indexes" => []},
    "fields" => [
      %{"name" => "name", "type" => "string"},
      %{"name" => "email", "type" => "string"}
    ],
    "relationships" => []
  }

  describe "diff/2 fields" do
    test "detects added field" do
      new =
        put_in(@base_old["fields"], [
          %{"name" => "name", "type" => "string"},
          %{"name" => "email", "type" => "string"},
          %{"name" => "mobile", "type" => "string"}
        ])

      plan = DiffEngine.diff(@base_old, new)

      assert %{fields: fields} = plan
      assert %{add: adds} = fields
      assert [%{name: "mobile", type: "string"}] = adds
    end

    test "detects removed field" do
      new =
        put_in(@base_old["fields"], [
          %{"name" => "name", "type" => "string"}
        ])

      plan = DiffEngine.diff(@base_old, new)

      assert %{fields: fields} = plan
      assert %{remove: removes} = fields
      assert [%{name: "email"}] = removes
    end

    test "detects field type change" do
      new =
        put_in(@base_old["fields"], [
          %{"name" => "name", "type" => "text"},
          %{"name" => "email", "type" => "string"}
        ])

      plan = DiffEngine.diff(@base_old, new)

      assert %{fields: fields} = plan
      assert %{change: changes} = fields
      assert [%{name: "name", from: "string", to: "text"}] = changes
    end

    test "detects field rename via compat.renames" do
      new =
        @base_old
        |> put_in(["fields"], [
          %{"name" => "full_name", "type" => "string"},
          %{"name" => "email", "type" => "string"}
        ])
        |> put_in(["ops"], %{
          "compat" => %{"renames" => [%{"from" => "name", "to" => "full_name"}]}
        })

      plan = DiffEngine.diff(@base_old, new)

      assert %{fields: fields} = plan
      assert %{rename: renames0} = fields

      renames =
        Enum.map(renames0, fn r -> %{from: r[:from] || r["from"], to: r[:to] || r["to"]} end)

      assert [%{from: "name", to: "full_name"}] = renames
    end
  end

  describe "diff/2 relationships" do
    test "detects added relationship" do
      new =
        put_in(@base_old["relationships"], [
          %{"name" => "posts", "kind" => "has_many", "target" => %{"slug" => "post"}}
        ])

      plan = DiffEngine.diff(@base_old, new)

      assert %{relationships: rels} = plan
      assert %{add: adds} = rels
      assert [%{name: "posts", kind: "has_many", target: %{"slug" => "post"}}] = adds
    end

    test "detects removed relationship" do
      old =
        put_in(@base_old["relationships"], [
          %{"name" => "posts", "kind" => "has_many", "target" => %{"slug" => "post"}}
        ])

      new = put_in(@base_old["relationships"], [])

      plan = DiffEngine.diff(old, new)

      assert %{relationships: rels} = plan
      assert %{remove: removes} = rels
      assert [%{name: "posts"}] = removes
    end
  end

  describe "diff/2 indexes" do
    test "detects unique index add/remove" do
      old = put_in(@base_old["storage"], %{"table" => "cms_authors", "indexes" => []})

      new =
        put_in(@base_old["storage"], %{
          "table" => "cms_authors",
          "indexes" => [
            %{"type" => "unique", "columns" => ["email"], "name" => "authors_email_unique"}
          ]
        })

      plan = DiffEngine.diff(old, new)

      assert %{indexes: idx} = plan
      assert %{add: adds} = idx
      assert [%{type: "unique", columns: ["email"], name: "authors_email_unique"}] = adds

      # reverse: remove
      plan2 = DiffEngine.diff(new, old)
      assert %{indexes: idx2} = plan2
      assert %{remove: removes} = idx2
      assert [%{type: "unique", columns: ["email"], name: "authors_email_unique"}] = removes
    end
  end

  test "plan defaults to empty lists when no changes" do
    plan = DiffEngine.diff(@base_old, @base_old)
    assert plan.fields == %{add: [], remove: [], change: [], rename: []}
    assert plan.relationships == %{add: [], remove: [], change: []}
    assert plan.indexes == %{add: [], remove: [], change: []}
  end
end
