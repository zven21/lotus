defmodule Lotus.CMS.Publisher.DiffEngine do
  @moduledoc """
  计算两份 ContentType 配置之间的差异，产出变更计划。

  当前支持：
  - 字段：新增、删除、类型变更、重命名（ops.compat.renames）
  - 关系：新增、删除
  - 索引：新增、删除（storage.indexes）
  """

  @type plan :: %{
          fields: %{add: list(), remove: list(), change: list(), rename: list()},
          relationships: %{add: list(), remove: list(), change: list()},
          indexes: %{add: list(), remove: list(), change: list()}
        }

  @spec diff(map(), map()) :: plan
  def diff(old, new) when is_map(old) and is_map(new) do
    %{
      fields: diff_fields(Map.get(old, "fields", []), Map.get(new, "fields", []), new),
      relationships:
        diff_relationships(Map.get(old, "relationships", []), Map.get(new, "relationships", [])),
      indexes:
        diff_indexes(
          get_in(old, ["storage", "indexes"]) || [],
          get_in(new, ["storage", "indexes"]) || []
        )
    }
  end

  defp diff_fields(old_fields, new_fields, new_config) do
    old_by_name = index_by(old_fields, "name")
    new_by_name = index_by(new_fields, "name")

    renames =
      get_in(new_config, ["ops", "compat", "renames"]) ||
        []
        |> Enum.map(fn r -> %{from: r["from"] || r[:from], to: r["to"] || r[:to]} end)

    added =
      (Map.keys(new_by_name) -- Map.keys(old_by_name))
      |> Enum.map(fn name ->
        %{
          name: name,
          type:
            get_in(new_by_name, [name, "type"]) || get_in(new_by_name, [name, "kind"]) || "string"
        }
      end)

    removed =
      (Map.keys(old_by_name) -- Map.keys(new_by_name))
      |> Enum.map(&%{name: &1})

    changed =
      Map.keys(new_by_name)
      |> Enum.filter(&Map.has_key?(old_by_name, &1))
      |> Enum.reduce([], fn name, acc ->
        old_t =
          get_in(old_by_name, [name, "type"]) || get_in(old_by_name, [name, "kind"]) || "string"

        new_t =
          get_in(new_by_name, [name, "type"]) || get_in(new_by_name, [name, "kind"]) || "string"

        if old_t != new_t, do: [%{name: name, from: old_t, to: new_t} | acc], else: acc
      end)
      |> Enum.reverse()

    %{add: added, remove: removed, change: changed, rename: renames}
  end

  defp diff_relationships(old_rels, new_rels) do
    old_by_name = index_by(old_rels, "name")
    new_by_name = index_by(new_rels, "name")

    added =
      (Map.keys(new_by_name) -- Map.keys(old_by_name))
      |> Enum.map(fn name -> Map.get(new_by_name, name) |> normalize_rel() end)

    removed =
      (Map.keys(old_by_name) -- Map.keys(new_by_name))
      |> Enum.map(&%{name: &1})

    %{add: added, remove: removed, change: []}
  end

  defp diff_indexes(old_indexes, new_indexes) do
    old_norm = Enum.map(old_indexes, &normalize_index/1)
    new_norm = Enum.map(new_indexes, &normalize_index/1)

    add = new_norm -- old_norm
    remove = old_norm -- new_norm

    %{add: add, remove: remove, change: []}
  end

  defp index_by(list, key) do
    list
    |> Enum.reduce(%{}, fn item, acc ->
      case item do
        %{} -> Map.put(acc, item[key], item)
        _ -> acc
      end
    end)
  end

  defp normalize_rel(rel) do
    %{
      name: rel["name"],
      kind: rel["kind"] || rel["type"],
      target: rel["target"]
    }
  end

  defp normalize_index(idx) do
    %{
      type: idx["type"] || "btree",
      columns: idx["columns"] || [],
      name: idx["name"]
    }
  end
end
