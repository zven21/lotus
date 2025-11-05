defmodule Lotus.CMS.Ash.ContentType do
  @moduledoc """
  Ash Resource: ContentType
  """
  use Ash.Resource,
    domain: Lotus.CMS.AshDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  # GraphQL 扩展暂时移除，避免类型名称冲突
  # extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table("content_types")
    repo(Lotus.Repo)
  end

  json_api do
    type("content_type")

    routes do
      base("/content_types")
      index(:read)
      get(:by_slug)
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  # GraphQL 配置暂时移除，避免类型名称冲突
  # graphql do
  #   type(:content_type)
  #
  #   queries do
  #     list(:content_types, :read)
  #     get(:content_type, :read)
  #   end
  #
  #   mutations do
  #     create(:create_content_type, :create)
  #     update(:update_content_type, :update)
  #     destroy(:destroy_content_type, :destroy)
  #   end
  # end

  identities do
    identity(:unique_slug, [:slug])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:slug, :string, allow_nil?: false, public?: true)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:description, :string, public?: true)
    attribute(:options, :map, default: %{}, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :fields, Lotus.CMS.Ash.ContentField do
      public?(true)
      destination_attribute(:content_type_id)
    end

    has_many :relations, Lotus.CMS.Ash.ContentRelation do
      public?(true)
      destination_attribute(:content_type_id)
    end

    # 已废弃：不再使用共享的 entries 表
    # has_many :entries, Lotus.CMS.Ash.Entry do
    #   public?(true)
    #   destination_attribute(:content_type_id)
    # end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:slug, :name, :description, :options])
    end

    update :update do
      accept([:slug, :name, :description, :options])
    end

    read :by_slug do
      get?(true)
      argument(:slug, :string, allow_nil?: false)
      filter(expr(slug == ^arg(:slug)))
    end
  end

  policies do
    # 暂时全部允许（后续按角色/租户收紧）
    policy always() do
      authorize_if(always())
    end
  end
end

defimpl String.Chars, for: Lotus.CMS.Ash.ContentType do
  def to_string(%{name: name}), do: name || ""
end

defmodule Lotus.CMS.Ash.ContentType.Manifest do
  @moduledoc """
  从已保存的 ContentType/ContentField 生成 CMS 配置清单（manifest）
  """
  alias Lotus.CMS.Ash.ContentType
  alias Lotus.CMS.Ash.ContentField
  alias Lotus.CMS.AshDomain

  require Ash.Query
  import Ash.Expr

  @doc """
  根据已保存的字段，构建 `{slug,name,description,fields}` 结构的 manifest 映射。
  支持传入 ContentType 结构体或其 id。
  """
  def build(%ContentType{id: id, slug: slug, name: name}), do: build_by_ids(id, slug, name)

  def build(content_type_id) when is_binary(content_type_id) do
    type = Ash.read_one!(ContentType, filter: expr(id == ^content_type_id), domain: AshDomain)
    build(type)
  end

  defp build_by_ids(id, slug, name) do
    query =
      ContentField
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(content_type_id == ^id))
      |> Ash.Query.sort(order: :asc)

    fields = Ash.read!(query, domain: AshDomain)

    %{
      "slug" => slug,
      "name" => name,
      "description" => to_string(name) <> " generated from saved content fields",
      "fields" =>
        Enum.map(fields, fn f ->
          %{
            "name" => f.name,
            "kind" => f.kind,
            "required" => f.required,
            "options" => f.options || %{}
          }
        end)
    }
  end
end
