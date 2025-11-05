defmodule Lotus.CMS.Publisher.Generators.Resource do
  @moduledoc """
  资源生成器

  职责：
  - 生成 Ash Resource 的基础结构（attributes, relationships, actions）
  - 生成 JSON:API 配置
  - 生成 GraphQL 配置
  """

  alias Lotus.CMS.Publisher.Generators.{Attributes, Relationships, Actions, Policies}
  alias Inflex

  @doc """
  生成完整的 Ash Resource 代码

  返回: {preamble_ast, contents_ast}
  """
  def generate(slug, type_id, config) do
    fields = Map.get(config, "fields", [])
    # 仅使用新配置键名 "relationships"
    relations = Map.get(config, "relationships", [])

    preamble =
      quote do
        use Ash.Resource,
          domain: Lotus.CMS.Generated,
          data_layer: AshPostgres.DataLayer,
          authorizers: [Ash.Policy.Authorizer],
          extensions: [AshJsonApi.Resource, AshGraphql.Resource],
          primary_read_warning?: false

        postgres do
          table(unquote("cms_#{Inflex.pluralize(slug)}"))
          repo(Lotus.Repo)
        end
      end

    attributes_ast = Attributes.generate(slug, type_id, fields, config)
    relationships_ast = Relationships.generate(slug, relations, config)
    actions_ast = Actions.generate(slug, type_id, fields, config)
    policies_ast = Policies.generate(slug, config)

    contents =
      quote do
        # JSON:API 配置
        unquote(generate_json_api_config(slug, config))

        # GraphQL 配置 - 使用基本的查询和变更
        unquote(generate_basic_graphql_config(slug, fields, relations))

        # Attributes
        unquote(attributes_ast)

        # Relationships
        unquote(relationships_ast)

        # Actions
        unquote(actions_ast)

        # Policies
        unquote(policies_ast)
      end

    {preamble, contents}
  end

  defp generate_json_api_config(slug, config) do
    api_config = Map.get(config, "api", %{})
    rest_config = Map.get(api_config, "rest", %{})

    base_path = Map.get(rest_config, "base_path", "/#{slug}")

    quote do
      json_api do
        type(unquote(slug))

        routes do
          base(unquote(base_path))
          index(:read)
          get(:read)
          post(:create)
          patch(:update)
          delete(:destroy)

          # TODO: 支持自定义路由配置
          # TODO: 支持嵌套路由
          # TODO: 支持批量操作路由
        end

        # TODO: 实现 rate limiting 配置
        # rate_limiting do
        #   max_requests: unquote(Map.get(rest_config, "rate_limiting", %{})["max_requests"])
        # end
      end
    end
  end

  defp generate_basic_graphql_config(slug, fields, relations) do
    plural = Inflex.pluralize(slug)
    pascal = Macro.camelize(slug)

    # 收集所有字段名（包括动态字段和关系字段）
    field_names =
      fields
      |> Enum.reject(&(Map.get(&1, "kind") == "relation"))
      |> Enum.map(&String.to_atom(&1["name"]))

    relation_names = Enum.map(relations, fn rel -> String.to_atom(rel["name"]) end)

    show_fields =
      [:id, :inserted_at, :updated_at] ++ field_names ++ relation_names

    quote do
      graphql do
        type(unquote(String.to_atom(slug)))

        show_fields(unquote(show_fields))

        queries do
          list(unquote(String.to_atom(plural)), :read)
          get(unquote(String.to_atom(slug)), :read)
        end

        mutations do
          create(unquote(String.to_atom("create" <> pascal)), :create)
          update(unquote(String.to_atom("update" <> pascal)), :update)
          destroy(unquote(String.to_atom("delete" <> pascal)), :destroy)
        end
      end
    end
  end

  # 已移除未使用的 generate_graphql_config/3（函数体删除）

  # 已移除未使用的 collect_queries/2（函数体删除）

  # 已移除未使用的 collect_mutations/2（函数体删除）

  # 已移除未使用的 collect_subscriptions/1（函数删除）
end
