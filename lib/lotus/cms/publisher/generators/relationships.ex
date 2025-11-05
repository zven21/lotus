defmodule Lotus.CMS.Publisher.Generators.Relationships do
  @moduledoc """
  关系生成器

  职责：
  - 生成 belongs_to, has_many, has_one, many_to_many 关系
  - 处理关系配置（on_delete, populate, filters）
  """

  @doc """
  生成 relationships 定义
  """
  def generate(slug, relations, config) do
    relationship_asts =
      Enum.map(relations, fn rel ->
        generate_relationship(rel, slug, config)
      end)

    quote do
      relationships do
        (unquote_splicing(relationship_asts))
      end
    end
  end

  defp generate_relationship(rel, slug, config) do
    rel_type = Map.get(rel, "type")
    rel_name = String.to_atom(Map.get(rel, "name"))
    target_slug = Map.get(rel, "target")
    target_module = Module.concat([Lotus.CMS.Generated, Recase.to_pascal(target_slug)])

    case rel_type do
      "manyToOne" -> generate_belongs_to(rel, rel_name, target_module)
      "oneToMany" -> generate_has_many(rel, rel_name, target_module, slug)
      "oneToOne" -> generate_has_one(rel, rel_name, target_module)
      "manyToMany" -> generate_many_to_many(rel, rel_name, target_module, slug, config)
      # 默认
      _ -> generate_belongs_to(rel, rel_name, target_module)
    end
  end

  defp generate_belongs_to(rel, rel_name, target_module) do
    foreign_key =
      case Map.get(rel, "foreign_key") do
        k when is_binary(k) -> String.to_atom(k)
        nil -> String.to_atom("#{rel_name}_id")
        k when is_atom(k) -> k
      end

    _on_delete = map_on_delete(Map.get(rel, "on_delete", "no_action"))

    quote do
      belongs_to unquote(rel_name), unquote(target_module) do
        public?(true)
        attribute_type(:uuid)
        destination_attribute(:id)
        source_attribute(unquote(foreign_key))

        # TODO: 支持 on_delete 配置
        # on_delete: unquote(on_delete)

        # TODO: 支持关系过滤配置
        # filter: ...
      end
    end
  end

  defp generate_has_many(rel, rel_name, target_module, source_slug) do
    target_field = Map.get(rel, "target_field")

    foreign_key =
      if target_field do
        String.to_atom("#{target_field}_id")
      else
        String.to_atom("#{source_slug}_id")
      end

    _on_delete = map_on_delete(Map.get(rel, "on_delete", "no_action"))
    _populate = Map.get(rel, "populate", %{})

    quote do
      has_many unquote(rel_name), unquote(target_module) do
        public?(true)
        destination_attribute(unquote(foreign_key))

        # TODO: 支持 on_delete 配置
        # TODO: 支持 populate 配置（auto_populate, max_depth）
        # TODO: 支持关系默认过滤
        # filter: ...
      end
    end
  end

  defp generate_has_one(rel, rel_name, target_module) do
    foreign_key = Map.get(rel, "foreign_key") || String.to_atom("#{rel_name}_id")

    quote do
      has_one unquote(rel_name), unquote(target_module) do
        public?(true)
        destination_attribute(unquote(foreign_key))

        # TODO: 支持 on_delete 配置
      end
    end
  end

  defp generate_many_to_many(_rel, _rel_name, _target_module, _source_slug, _config) do
    # TODO: 暂时禁用 many_to_many 关系生成，需要先创建中间表资源
    # through_table = Map.get(rel, "through") || "#{source_slug}_#{rel["name"]}"
    # join_table = Map.get(rel, "join_table", %{})
    # 
    # left_key = Map.get(join_table, "left_key") || "#{source_slug}_id"
    # right_key = Map.get(join_table, "right_key") || "#{rel["target"]}_id"

    quote do
      # TODO: 实现 many_to_many 关系
      # 需要先创建中间表资源，然后使用：
      # many_to_many unquote(rel_name), unquote(target_module) do
      #   public?(true)
      #   through(unquote(String.to_atom(through_table)))
      #   source_attribute_on_join(unquote(String.to_atom(left_key)))
      #   destination_attribute_on_join(unquote(String.to_atom(right_key)))
      # end
    end
  end

  defp map_on_delete("cascade"), do: :delete
  defp map_on_delete("restrict"), do: :restrict
  defp map_on_delete("set_null"), do: :nilify
  defp map_on_delete("no_action"), do: :nothing
  defp map_on_delete(_), do: :nothing
end
