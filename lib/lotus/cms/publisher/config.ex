defmodule Lotus.CMS.Publisher.Config do
  @moduledoc """
  配置加载和验证模块

  职责：
  - 加载 JSON/YAML 配置文件
  - 验证配置格式和完整性
  - 规范化配置结构
  """

  @doc """
  加载配置文件（支持 JSON 和 YAML）
  """
  def load_file(path) do
    cond do
      String.ends_with?(path, ".json") ->
        with {:ok, bin} <- File.read(path),
             {:ok, config} <- Jason.decode(bin) do
          {:ok, config}
        else
          error -> error
        end

      String.ends_with?(path, [".yaml", ".yml"]) ->
        with {:ok, bin} <- File.read(path),
             {:ok, config} <- YamlElixir.read_from_string(bin) do
          {:ok, config}
        else
          error -> error
        end

      true ->
        {:error, :unsupported_format}
    end
  end

  @doc """
  验证配置文件的必要字段
  """
  def validate(config) do
    with :ok <- validate_required_fields(config),
         :ok <- validate_slug(config),
         :ok <- validate_fields(config),
         :ok <- validate_relationships(config) do
      {:ok, config}
    else
      error -> error
    end
  end

  defp validate_required_fields(config) do
    required = ["slug", "name"]

    missing =
      Enum.filter(required, fn key ->
        not Map.has_key?(config, key) or is_nil(config[key])
      end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_slug(config) do
    slug = config["slug"]

    if is_binary(slug) and slug != "" and String.match?(slug, ~r/^[a-z][a-z0-9_]*$/) do
      :ok
    else
      {:error, {:invalid_slug, slug}}
    end
  end

  defp validate_fields(config) do
    _fields = config["fields"] || []

    # TODO: 实现字段验证逻辑
    # - 检查字段名称格式
    # - 检查字段类型有效性
    # - 检查字段选项一致性
    # - 检查唯一性约束

    :ok
  end

  defp validate_relationships(config) do
    _relationships = config["relationships"] || []

    # TODO: 实现关系验证逻辑
    # - 检查目标类型是否存在
    # - 检查关系类型有效性
    # - 检查外键字段是否存在
    # - 检查循环引用

    :ok
  end

  @doc """
  规范化配置，填充默认值
  """
  def normalize(config) do
    config
    |> ensure_default_options()
    |> ensure_default_fields()
    |> ensure_default_relations()
    |> ensure_default_permissions()
    |> ensure_default_search()
    |> ensure_default_filtering()
  end

  defp ensure_default_options(config) do
    default_options = %{
      "versionable" => false,
      "draftable" => true,
      "i18n" => false,
      "singleton" => false,
      "timestamps" => true
    }

    options = Map.get(config, "options", %{})
    merged_options = Map.merge(default_options, options)

    Map.put(config, "options", merged_options)
  end

  defp ensure_default_fields(config) do
    fields = Map.get(config, "fields", [])
    Map.put(config, "fields", fields)
  end

  defp ensure_default_relations(config) do
    relationships = Map.get(config, "relationships", [])
    Map.put(config, "relationships", relationships)
  end

  defp ensure_default_permissions(config) do
    permissions = Map.get(config, "permissions", %{})

    default_permissions = %{
      "enabled" => false,
      "default_role" => "authenticated",
      "roles" => %{}
    }

    merged = Map.merge(default_permissions, permissions)
    Map.put(config, "permissions", merged)
  end

  defp ensure_default_search(config) do
    search = Map.get(config, "search", %{})

    default_search = %{
      "enabled" => false,
      "strategy" => "like",
      "filters" => %{
        "status" => false,
        "date_range" => false,
        "relations" => false
      }
    }

    merged = Map.merge(default_search, search)
    Map.put(config, "search", merged)
  end

  defp ensure_default_filtering(config) do
    filtering = Map.get(config, "filtering", %{})

    default_filtering = %{
      "enabled" => true,
      "filterable_fields" => [],
      "sortable_fields" => ["created_at", "updated_at"],
      "default_sort" => %{
        "field" => "created_at",
        "direction" => "desc"
      }
    }

    merged = Map.merge(default_filtering, filtering)
    Map.put(config, "filtering", merged)
  end
end
