defmodule Lotus.CMS.Publisher.ProjectionSync do
  @moduledoc """
  从 ContentType.config 同步投影到 `content_fields` 与 `content_relations`。

  - 单一入口：sync(content_type_id, config)
  - 幂等：重复执行不会产生重复记录
  - 差异对齐：创建缺失、更新变更、删除多余
  """

  import Ecto.Query
  alias Lotus.Repo
  alias Lotus.CMS.ContentField
  alias Lotus.CMS.Ash.ContentRelation
  alias Lotus.CMS.AshDomain

  @doc """
  同步指定内容类型的字段与关系。
  """
  def sync(content_type_id, config) when is_binary(content_type_id) and is_map(config) do
    Repo.transaction(fn ->
      :ok = sync_fields(content_type_id, Map.get(config, "fields", []) || [])
      :ok = sync_relations(content_type_id, Map.get(config, "relationships", []) || [])
      :ok
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, e} -> {:error, e}
    end
  end

  # 同步字段
  defp sync_fields(content_type_id, fields) do
    existing =
      Repo.all(from f in ContentField, where: f.content_type_id == ^content_type_id)
      |> Map.new(&{&1.name, &1})

    desired =
      fields
      |> Enum.with_index()
      |> Enum.map(fn {f, idx} ->
        {f["name"],
         %{
           name: f["name"],
           kind: map_field_type_to_kind(f["type"]),
           required: not Map.get(f, "nullable", true),
           unique: Map.get(f, "unique", false),
           default: Map.get(f, "default"),
           order: idx,
           options: Map.drop(f, ["name", "type", "nullable", "unique", "default"]) |> Map.new()
         }}
      end)
      |> Map.new()

    # upsert/update
    Enum.each(desired, fn {name, attrs} ->
      case Map.get(existing, name) do
        nil ->
          %ContentField{id: Ecto.UUID.generate(), content_type_id: content_type_id}
          |> ContentField.changeset(attrs)
          |> Repo.insert!()

        %ContentField{} = rec ->
          rec
          |> ContentField.changeset(attrs)
          |> Repo.update!()
      end
    end)

    # delete removed
    to_delete = Map.keys(existing) -- Map.keys(desired)

    from(f in ContentField,
      where: f.content_type_id == ^content_type_id and f.name in ^to_delete
    )
    |> Repo.delete_all()

    :ok
  end

  # 同步关系
  defp sync_relations(content_type_id, relationships) do
    existing =
      ContentRelation
      |> Ash.read!(domain: AshDomain)
      |> Enum.filter(&(&1.content_type_id == content_type_id))
      |> Map.new(&{&1.name, &1})

    desired =
      relationships
      |> Enum.map(fn r ->
        name = r["name"]
        kind = r["kind"] || r["type"]
        target = r["target"]
        target_slug = if is_map(target), do: target["slug"], else: target
        fk = Map.get(r, "foreign_key") || default_fk(kind, name)

        {name,
         %{
           content_type_id: content_type_id,
           name: name,
           type: map_kind(kind),
           target: target_slug,
           foreign_key: fk,
           target_field: Map.get(r, "target_field"),
           on_delete: Map.get(r, "on_delete", "restrict"),
           through: Map.get(r, "through"),
           options:
             Map.drop(r, [
               "name",
               "kind",
               "type",
               "target",
               "foreign_key",
               "target_field",
               "on_delete",
               "through"
             ])
             |> Map.new()
         }}
      end)
      |> Map.new()

    # upsert/update
    Enum.each(desired, fn {name, attrs} ->
      case Map.get(existing, name) do
        nil ->
          {:ok, _} = Ash.create(ContentRelation, attrs, domain: AshDomain)

        rec ->
          {:ok, _} = Ash.update(rec, attrs, domain: AshDomain)
      end
    end)

    # delete removed
    to_delete = Map.keys(existing) -- Map.keys(desired)

    Enum.each(to_delete, fn name ->
      rec = Map.fetch!(existing, name)

      case Ash.destroy(rec, domain: AshDomain) do
        :ok -> :ok
        {:ok, _} -> :ok
        other -> raise "failed to destroy relation #{name}: #{inspect(other)}"
      end
    end)

    :ok
  end

  defp map_field_type_to_kind(nil), do: "string"
  defp map_field_type_to_kind(type), do: to_string(type)

  defp map_kind("belongs_to"), do: "manyToOne"
  defp map_kind("has_one"), do: "oneToOne"
  defp map_kind("has_many"), do: "oneToMany"
  defp map_kind("many_to_many"), do: "manyToMany"
  defp map_kind("manyToOne"), do: "manyToOne"
  defp map_kind("oneToOne"), do: "oneToOne"
  defp map_kind("oneToMany"), do: "oneToMany"
  defp map_kind("manyToMany"), do: "manyToMany"
  defp map_kind(other), do: to_string(other)

  defp default_fk("belongs_to", name) when is_binary(name), do: name <> "_id"
  defp default_fk(_, _), do: nil
end
