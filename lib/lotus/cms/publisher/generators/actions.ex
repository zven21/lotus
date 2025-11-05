defmodule Lotus.CMS.Publisher.Generators.Actions do
  @moduledoc """
  动作生成器

  职责：
  - 生成 read, create, update, destroy 动作
  - 生成自定义动作（publish, unpublish）
  - 生成搜索和过滤逻辑
  - 生成验证逻辑
  """

  alias Lotus.CMS.Publisher.Generators.Validations

  @doc """
  生成 actions 定义
  """
  def generate(slug, _type_id, fields, config) do
    read_action = generate_read_action(slug, fields, config)
    create_action = generate_create_action(slug, fields, config)
    update_action = generate_update_action(slug, fields, config)
    destroy_action = quote(do: defaults([:destroy]))

    custom_actions = []

    quote do
      actions do
        unquote(destroy_action)
        unquote(read_action)
        unquote(create_action)
        unquote(update_action)
        (unquote_splicing(custom_actions))
      end
    end
  end

  defp generate_read_action(_slug, _fields, _config) do
    quote do
      read :read do
        primary?(true)
      end
    end
  end

  # defp collect_read_arguments(config) do
  #   arguments = [
  #     quote(do: argument(:q, :string, allow_nil?: true)),
  #     quote(do: argument(:status, :string, allow_nil?: true))
  #     # locale argument removed (i18n disabled)
  #     # quote(do: argument(:locale, :string, allow_nil?: true))
  #   ]

  #   # 从关系配置中收集过滤参数
  #   relations = Map.get(config, "relations", [])

  #   relation_args =
  #     Enum.map(relations, fn rel ->
  #       foreign_key = Map.get(rel, "foreign_key") || "#{rel["name"]}_id"
  #       quote(do: argument(unquote(String.to_atom(foreign_key)), :uuid, allow_nil?: true))
  #     end)

  #   # 分页参数
  #   pagination_args = [
  #     quote(do: argument(:page, :integer, default: 1, allow_nil?: false)),
  #     quote(do: argument(:page_size, :integer, default: 20, allow_nil?: false))
  #   ]

  #   # 排序参数
  #   sorting_args = [
  #     quote(do: argument(:sort, :string, allow_nil?: true))
  #   ]

  #   arguments ++ relation_args ++ pagination_args ++ sorting_args
  # end

  defp generate_create_action(_slug, fields, config) do
    dynamic_fields =
      fields
      |> Enum.reject(&(Map.get(&1, "kind") == "relation"))
      |> Enum.map(&String.to_atom(&1["name"]))

    # 添加关系的外键字段到 accept 列表（仅使用新键名 relationships）
    relations = Map.get(config, "relationships", [])

    foreign_key_fields =
      relations
      |> Enum.filter(fn rel -> Map.get(rel, "type") == "manyToOne" end)
      |> Enum.map(fn rel ->
        foreign_key = Map.get(rel, "foreign_key") || "#{Map.get(rel, "name")}_id"
        String.to_atom(foreign_key)
      end)

    accept_fields = dynamic_fields ++ foreign_key_fields
    changes = generate_changes(config, :create)
    validations = Validations.generate_changeset_validations(fields, config)

    quote do
      create :create do
        primary?(true)
        accept(unquote(accept_fields))

        # 验证逻辑
        unquote_splicing(validations)

        # 变更钩子
        unquote_splicing(changes)

        # TODO: 处理强类型字段（如果有）
        # if config["options"]["strong_typing"] do
        #   change(extract_fields_to_columns())
        # end
      end
    end
  end

  defp generate_update_action(_slug, fields, config) do
    dynamic_fields =
      fields
      |> Enum.reject(&(Map.get(&1, "kind") == "relation"))
      |> Enum.map(&String.to_atom(&1["name"]))

    # 添加关系的外键字段到 accept 列表（仅使用新键名 relationships）
    relations = Map.get(config, "relationships", [])

    foreign_key_fields =
      relations
      |> Enum.filter(fn rel -> Map.get(rel, "type") == "manyToOne" end)
      |> Enum.map(fn rel ->
        foreign_key = Map.get(rel, "foreign_key") || "#{Map.get(rel, "name")}_id"
        String.to_atom(foreign_key)
      end)

    accept_fields = dynamic_fields ++ foreign_key_fields
    changes = generate_changes(config, :update)
    validations = Validations.generate_changeset_validations(fields, config)

    quote do
      update :update do
        primary?(true)
        accept(unquote(accept_fields))

        # 验证逻辑
        unquote_splicing(validations)

        # 变更钩子
        unquote_splicing(changes)

        # TODO: 版本化支持
        # if config["options"]["versionable"] do
        #   change(create_version_before_update())
        # end
      end
    end
  end

  # 自定义发布/取消发布动作暂不需要（移除 status/published_at 相关逻辑）

  defp generate_changes(config, action) do
    hooks_config = Map.get(config, "hooks", %{})

    _before_hooks =
      case action do
        :create -> Map.get(hooks_config, "before_create", [])
        :update -> Map.get(hooks_config, "before_update", [])
        _ -> []
      end

    _after_hooks =
      case action do
        :create -> Map.get(hooks_config, "after_create", [])
        :update -> Map.get(hooks_config, "after_update", [])
        _ -> []
      end

    # TODO: 生成钩子变更
    # Hooks.generate_hook_changes(before_hooks ++ after_hooks)

    # TODO: 生成审计变更
    # Audit.generate_audit_changes(config, action)

    []
  end
end
