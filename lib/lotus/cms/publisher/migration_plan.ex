defmodule Lotus.CMS.Publisher.MigrationPlan do
  @moduledoc """
  根据 old/new 配置与 diff 生成数据库迁移计划（抽象操作列表）。

  输出结构：
  %{
    table: String.t(),
    operations: [op]
  }

  其中 op:
  - {:add_column, field_atom, ecto_type | {:references, table_atom, type_atom, keyword}}
  - {:drop_column, field_atom}
  - {:alter_column_type, field_atom, ecto_type}
  - {:rename_column, from_atom, to_atom}
  - {:add_index, [field_atoms]}
  - {:create_unique_index, [field_atoms], index_name_atom}
  - {:drop_unique_index, [field_atoms], index_name_atom}
  """

  @type t :: %{table: String.t(), operations: list()}

  @spec generate(map(), map(), map()) :: t
  def generate(old, new, diff) do
    table = get_in(new, ["storage", "table"]) || get_in(old, ["storage", "table"]) || ""

    if initial_create?(old) do
      ops = plan_create_table(new)
      %{table: table, operations: ops}
    else
      ops = []
      ops = ops ++ plan_field_renames(diff)
      ops = ops ++ plan_field_adds(diff, new)
      ops = ops ++ plan_field_removes(diff)
      ops = ops ++ plan_field_type_changes(diff)
      ops = ops ++ plan_relationship_adds(diff, new)
      ops = ops ++ plan_indexes(diff)
      %{table: table, operations: ops}
    end
  end

  defp initial_create?(old) do
    published? = Map.get(old, "published", false)

    not published? and (get_in(old, ["fields"]) || []) == [] and
      (get_in(old, ["relationships"]) || []) == []
  end

  defp plan_create_table(new) do
    fields = get_in(new, ["fields"]) || []
    rels = get_in(new, ["relationships"]) || []
    idxs = get_in(new, ["storage", "indexes"]) || []

    # columns from fields
    field_cols =
      Enum.map(fields, fn f ->
        {:add_column, String.to_atom(f["name"]), map_type(f["type"] || f["kind"])}
      end)

    # belongs_to FKs
    fk_cols =
      rels
      |> Enum.filter(fn r -> (r["kind"] || r["type"]) in ["belongs_to", "manyToOne"] end)
      |> Enum.flat_map(fn r ->
        name = r["name"]
        target = r["target"]
        slug = if is_map(target), do: target["slug"], else: target
        target_table = target_table(new, slug)
        fk = String.to_atom(name <> "_id")

        [
          {:add_column, fk, {:references, target_table, :uuid, on_delete: :restrict}},
          {:add_index, [fk]}
        ]
      end)

    unique_ops =
      Enum.flat_map(idxs, fn i ->
        case i do
          %{"type" => "unique", "columns" => cols, "name" => name} ->
            [{:create_unique_index, Enum.map(cols, &String.to_atom/1), String.to_atom(name)}]

          _ ->
            []
        end
      end)

    [{:create_table}] ++ field_cols ++ fk_cols ++ unique_ops
  end

  defp plan_field_renames(%{fields: %{rename: renames}}) do
    Enum.map(renames, fn r ->
      from = r[:from] || r["from"]
      to = r[:to] || r["to"]
      {:rename_column, String.to_atom(from), String.to_atom(to)}
    end)
  end

  defp plan_field_renames(_), do: []

  defp plan_field_adds(%{fields: %{add: adds}}, _new) do
    Enum.map(adds, fn %{name: name, type: type} ->
      {:add_column, String.to_atom(name), map_type(type)}
    end)
  end

  defp plan_field_adds(_diff, _new), do: []

  defp plan_field_removes(%{fields: %{remove: removes}}) do
    Enum.map(removes, fn %{name: name} -> {:drop_column, String.to_atom(name)} end)
  end

  defp plan_field_removes(_), do: []

  defp plan_field_type_changes(%{fields: %{change: changes}}) do
    Enum.map(changes, fn %{name: name, to: to_type} ->
      {:alter_column_type, String.to_atom(name), map_type(to_type)}
    end)
  end

  defp plan_field_type_changes(_), do: []

  defp plan_relationship_adds(%{relationships: %{add: adds}}, new) do
    Enum.flat_map(adds, fn rel ->
      kind = rel[:kind] || rel["kind"]

      case kind do
        "belongs_to" ->
          fk_col = String.to_atom("#{rel[:name] || rel["name"]}_id")
          target = rel[:target] || rel["target"] || %{}
          target_slug = target["slug"] || target[:slug]
          table = target_table(new, target_slug)

          [
            {:add_column, fk_col, {:references, table, :uuid, on_delete: :restrict}},
            {:add_index, [fk_col]}
          ]

        _ ->
          []
      end
    end)
  end

  defp plan_relationship_adds(_, _), do: []

  defp plan_indexes(%{indexes: %{add: adds, remove: removes}}) do
    create_ops =
      Enum.flat_map(adds, fn idx ->
        case idx do
          %{type: "unique", columns: cols, name: name} ->
            [
              {:create_unique_index, Enum.map(cols, &String.to_atom/1), String.to_atom(name)}
            ]

          _ ->
            []
        end
      end)

    drop_ops =
      Enum.flat_map(removes, fn idx ->
        case idx do
          %{type: "unique", columns: cols, name: name} ->
            [
              {:drop_unique_index, Enum.map(cols, &String.to_atom/1), String.to_atom(name)}
            ]

          _ ->
            []
        end
      end)

    create_ops ++ drop_ops
  end

  defp plan_indexes(_), do: []

  defp map_type("string"), do: :string
  defp map_type("text"), do: :text
  defp map_type("integer"), do: :integer
  defp map_type("decimal"), do: :decimal
  defp map_type("boolean"), do: :boolean
  defp map_type("date"), do: :date
  defp map_type("datetime"), do: :utc_datetime_usec
  defp map_type("json"), do: :jsonb
  defp map_type(_), do: :string

  defp target_table(new, slug) when is_binary(slug) do
    plural = Inflex.pluralize(slug)
    String.to_atom("cms_" <> plural)
  end

  defp target_table(_new, _), do: :unknown
end
