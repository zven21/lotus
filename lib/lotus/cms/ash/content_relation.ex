defmodule Lotus.CMS.Ash.ContentRelation do
  @moduledoc """
  Ash Resource: ContentRelation
  存储内容类型之间的关系定义（元数据）
  """
  use Ash.Resource,
    domain: Lotus.CMS.AshDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  # GraphQL 扩展暂时移除，避免类型名称冲突
  # extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table("content_relations")
    repo(Lotus.Repo)
  end

  json_api do
    type("content_relation")

    routes do
      base("/content_relations")
      index(:read)
      get(:read)
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  # GraphQL 配置暂时移除，避免类型名称冲突
  # graphql do
  #   type(:content_relation)
  #
  #   queries do
  #     list(:content_relations, :read)
  #     get(:content_relation, :read)
  #   end
  #
  #   mutations do
  #     create(:create_content_relation, :create)
  #     update(:update_content_relation, :update)
  #     destroy(:destroy_content_relation, :destroy)
  #   end
  # end

  attributes do
    uuid_primary_key(:id)
    attribute(:content_type_id, :uuid, allow_nil?: false, public?: true)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:type, :string, allow_nil?: false, public?: true)
    # type: 'manyToOne', 'oneToMany', 'manyToMany', 'oneToOne'
    attribute(:target, :string, allow_nil?: false, public?: true)
    # target: 目标内容类型的 slug
    attribute(:foreign_key, :string, public?: true)
    attribute(:target_field, :string, public?: true)
    attribute(:on_delete, :string, default: "restrict", public?: true)
    # on_delete: 'cascade', 'restrict', 'set_null', 'no_action'
    attribute(:through, :string, public?: true)
    # through: manyToMany 的联结表名
    attribute(:options, :map, default: %{}, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :content_type, Lotus.CMS.Ash.ContentType do
      public?(true)
      attribute_type(:uuid)
      destination_attribute(:id)
      source_attribute(:content_type_id)
    end
  end

  identities do
    identity(:unique_name_per_type, [:content_type_id, :name])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :content_type_id,
        :name,
        :type,
        :target,
        :foreign_key,
        :target_field,
        :on_delete,
        :through,
        :options
      ])
    end

    update :update do
      accept([:name, :type, :target, :foreign_key, :target_field, :on_delete, :through, :options])
    end
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end
end
