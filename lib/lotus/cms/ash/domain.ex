defmodule Lotus.CMS.AshDomain do
  @moduledoc """
  Ash Domain：聚合 CMS 相关资源
  """
  use Ash.Domain,
    extensions: [AshJsonApi.Domain]

  # GraphQL 扩展暂时移除，避免与 Generated domain 的类型名称冲突
  # extensions: [AshJsonApi.Domain, AshGraphql.Domain]

  resources do
    resource(Lotus.CMS.Ash.ContentType)
    resource(Lotus.CMS.Ash.ContentField)
    resource(Lotus.CMS.Ash.ContentRelation)
  end
end
