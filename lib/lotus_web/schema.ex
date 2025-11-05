defmodule LotusWeb.Schema do
  use Absinthe.Schema

  # Import custom scalars and types
  # import_types(LotusWeb.GraphQL.Scalars.JsonData)
  # 注意：在强类型列模式下，不再使用动态生成的 *_data 类型
  # import_types(LotusWeb.GraphQL.GeneratedTypes)

  # GraphQL 暂时禁用，当前阶段专注于 JSON:API
  # 后续可以通过配置 type_prefix 或命名空间解决类型冲突后再启用
  use AshGraphql, domains: [Lotus.CMS.Generated]

  # Absinthe requires a query root（占位符，GraphQL 已禁用）
  query do
    field :_placeholder, :string do
      resolve(fn _, _ -> {:ok, "GraphQL disabled - JSON:API only"} end)
    end
  end

  mutation do
    field :_placeholder, :string do
      resolve(fn _, _ -> {:ok, "GraphQL disabled - JSON:API only"} end)
    end
  end
end
