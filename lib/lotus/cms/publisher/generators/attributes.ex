defmodule Lotus.CMS.Publisher.Generators.Attributes do
  @moduledoc """
  属性生成器

  职责：
  - 生成基础的 attributes（id, content_type_id, status, locale, data, etc.）
  - 生成计算字段（calculations）用于从 data map 中提取字段值
  - 为搜索和过滤生成计算字段
  """

  @doc """
  生成 attributes 定义
  """
  def generate(_slug, _type_id, fields, config) do
    base_attributes = generate_base_attributes()
    field_attributes = generate_field_attributes(fields)
    calculations = generate_calculations(fields, config)

    attributes_ast =
      quote do
        attributes do
          (unquote_splicing(base_attributes))
          (unquote_splicing(field_attributes))
        end
      end

    # 只有在有计算字段时才生成 calculations 块
    calculations_ast =
      if length(calculations) > 0 do
        quote do
          calculations do
            (unquote_splicing(calculations))
          end
        end
      else
        # 不生成 calculations 块
        []
      end

    if calculations_ast != [] do
      quote do
        unquote(attributes_ast)
        unquote(calculations_ast)
      end
    else
      attributes_ast
    end
  end

  defp generate_base_attributes() do
    [
      quote(do: uuid_primary_key(:id)),
      # status 与 published_at 暂不需要
      quote(do: create_timestamp(:inserted_at)),
      quote(do: update_timestamp(:updated_at))
    ]
  end

  defp generate_field_attributes(fields) do
    fields
    |> Enum.reject(&(Map.get(&1, "kind") == "relation"))
    |> Enum.map(fn field ->
      name_atom = String.to_atom(Map.get(field, "name"))
      kind = Map.get(field, "kind", "string")
      required = Map.get(field, "required", false)
      ash_type = map_kind_to_ash_type(kind)

      quote do
        attribute(unquote(name_atom), unquote(ash_type),
          allow_nil?: unquote(!required),
          public?: true
        )
      end
    end)
  end

  defp generate_calculations(_fields, config) do
    # 为每个可搜索字段生成计算字段，用于从 data 中提取值
    _searchable_fields = Map.get(config, "searchable_fields", [])

    # TODO: 暂时禁用计算字段生成，待搜索功能实现后再启用
    # calculations = 
    #   Enum.map(searchable_fields, fn field_name ->
    #     generate_field_calculation(field_name, fields)
    #   end)
    # 
    # # 如果启用搜索，生成全文搜索计算字段
    # search_config = Map.get(config, "search", %{})
    # 
    # calculations = if Map.get(search_config, "enabled", false) do
    #   [generate_fulltext_calculation(searchable_fields, search_config) | calculations]
    # else
    #   calculations
    # end

    # 暂时返回空列表，不生成任何计算字段
    []
  end

  # 已移除未使用的 generate_field_calculation/2
  # defp generate_field_calculation(field_name, fields) do
  #   ...removed...
  # end

  # 已移除未使用的 generate_fulltext_calculation/2

  defp map_kind_to_ash_type("string"), do: :string
  defp map_kind_to_ash_type("text"), do: :string
  defp map_kind_to_ash_type("integer"), do: :integer
  defp map_kind_to_ash_type("decimal"), do: :decimal
  defp map_kind_to_ash_type("boolean"), do: :boolean
  defp map_kind_to_ash_type("date"), do: :date
  defp map_kind_to_ash_type("datetime"), do: :utc_datetime
  defp map_kind_to_ash_type("json"), do: :map
  defp map_kind_to_ash_type("enum"), do: :atom
  defp map_kind_to_ash_type(_kind), do: :string
end
