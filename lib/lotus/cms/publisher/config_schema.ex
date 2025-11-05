defmodule Lotus.CMS.Publisher.ConfigSchema do
  @moduledoc """
  ContentType.config JSON Schema 验证器

  职责：
  - 验证配置结构符合 JSON Schema 规范
  - 检查必填字段、类型、格式
  - 返回清晰的错误信息
  """

  @valid_field_types ~w(string text integer decimal boolean date datetime json enum)
  @valid_relationship_kinds ~w(belongs_to has_one has_many many_to_many)
  @slug_pattern ~r/^[a-z][a-z0-9_]*$/

  @doc """
  验证配置是否符合 Schema 规范

  返回：
  - `{:ok, validated_config}` - 配置有效
  - `{:error, errors}` - 配置无效，errors 是关键字列表
  """
  def validate(config) when is_map(config) do
    errors = %{}

    errors =
      errors
      |> validate_meta(config)
      |> validate_storage(config)
      |> validate_fields(config)
      |> validate_relationships(config)
      |> validate_optional_sections(config)

    if map_size(errors) == 0 do
      {:ok, config}
    else
      {:error, Map.to_list(errors)}
    end
  end

  def validate(_), do: {:error, [root: "config must be a map"]}

  # 验证 meta 部分
  defp validate_meta(errors, config) do
    case Map.get(config, "meta") do
      nil ->
        Map.put(errors, :meta, "meta field is required")

      meta when is_map(meta) ->
        meta_errors = %{}

        meta_errors =
          if not Map.has_key?(meta, "version") or is_nil(meta["version"]) do
            Map.put(meta_errors, :version, "meta.version is required")
          else
            meta_errors
          end

        meta_errors =
          if not Map.has_key?(meta, "name") or is_nil(meta["name"]) do
            Map.put(meta_errors, :name, "meta.name is required")
          else
            meta_errors
          end

        meta_errors =
          if not Map.has_key?(meta, "slug") or is_nil(meta["slug"]) do
            Map.put(meta_errors, :slug, "meta.slug is required")
          else
            slug = meta["slug"]

            if not is_binary(slug) or not Regex.match?(@slug_pattern, slug) do
              Map.put(meta_errors, :slug, "meta.slug must match pattern: ^[a-z][a-z0-9_]*$")
            else
              meta_errors
            end
          end

        if map_size(meta_errors) == 0 do
          errors
        else
          Map.put(errors, :meta, Map.to_list(meta_errors))
        end

      _ ->
        Map.put(errors, :meta, "meta must be a map")
    end
  end

  # 验证 storage 部分
  defp validate_storage(errors, config) do
    case Map.get(config, "storage") do
      nil ->
        Map.put(errors, :storage, "storage field is required")

      storage when is_map(storage) ->
        storage_errors = %{}

        storage_errors =
          if not Map.has_key?(storage, "table") or is_nil(storage["table"]) do
            Map.put(storage_errors, :table, "storage.table is required")
          else
            storage_errors
          end

        if map_size(storage_errors) == 0 do
          errors
        else
          Map.put(errors, :storage, Map.to_list(storage_errors))
        end

      _ ->
        Map.put(errors, :storage, "storage must be a map")
    end
  end

  # 验证 fields 数组
  defp validate_fields(errors, config) do
    fields = Map.get(config, "fields", [])

    if is_list(fields) do
      field_errors =
        fields
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {field, index}, acc ->
          Map.merge(acc, validate_field(field, index))
        end)

      if map_size(field_errors) == 0 do
        errors
      else
        Map.put(errors, :fields, Map.to_list(field_errors))
      end
    else
      Map.put(errors, :fields, "fields must be a list")
    end
  end

  # 验证单个 field
  defp validate_field(field, index) when is_map(field) do
    errors = %{}

    errors =
      if not Map.has_key?(field, "name") or is_nil(field["name"]) do
        Map.put(errors, :"fields[#{index}].name", "field.name is required")
      else
        errors
      end

    errors =
      if not Map.has_key?(field, "type") or is_nil(field["type"]) do
        Map.put(errors, :"fields[#{index}].type", "field.type is required")
      else
        field_type = field["type"]

        if field_type not in @valid_field_types do
          Map.put(
            errors,
            :"fields[#{index}].type",
            "field.type must be one of: #{Enum.join(@valid_field_types, ", ")}"
          )
        else
          errors
        end
      end

    errors
  end

  defp validate_field(_field, index), do: %{:"fields[#{index}]" => "field must be a map"}

  # 验证 relationships 数组
  defp validate_relationships(errors, config) do
    relationships = Map.get(config, "relationships", [])

    if is_list(relationships) do
      relation_errors =
        relationships
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {relation, index}, acc ->
          Map.merge(acc, validate_relationship(relation, index))
        end)

      if map_size(relation_errors) == 0 do
        errors
      else
        Map.put(errors, :relationships, Map.to_list(relation_errors))
      end
    else
      if is_nil(relationships) do
        # relationships 是可选的，nil 表示没有关系
        errors
      else
        Map.put(errors, :relationships, "relationships must be a list")
      end
    end
  end

  # 验证单个 relationship
  defp validate_relationship(relation, index) when is_map(relation) do
    errors = %{}

    errors =
      if not Map.has_key?(relation, "name") or is_nil(relation["name"]) do
        Map.put(errors, :"relationships[#{index}].name", "relationship.name is required")
      else
        errors
      end

    errors =
      if not Map.has_key?(relation, "kind") or is_nil(relation["kind"]) do
        Map.put(errors, :"relationships[#{index}].kind", "relationship.kind is required")
      else
        kind = relation["kind"]

        if kind not in @valid_relationship_kinds do
          Map.put(
            errors,
            :"relationships[#{index}].kind",
            "relationship.kind must be one of: #{Enum.join(@valid_relationship_kinds, ", ")}"
          )
        else
          errors
        end
      end

    errors
  end

  defp validate_relationship(_relation, index),
    do: %{:"relationships[#{index}]" => "relationship must be a map"}

  # 验证可选部分（features, policies 等），目前只检查是否为 map（如果存在）
  defp validate_optional_sections(errors, config) do
    optional_sections = ["features", "policies", "validation", "ops"]

    Enum.reduce(optional_sections, errors, fn section_key, acc ->
      case Map.get(config, section_key) do
        nil ->
          acc

        value when is_map(value) ->
          acc

        _ ->
          Map.put(acc, String.to_atom(section_key), "#{section_key} must be a map")
      end
    end)
  end
end
