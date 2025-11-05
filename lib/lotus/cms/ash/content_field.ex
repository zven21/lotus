defmodule Lotus.CMS.Ash.ContentField do
  @moduledoc """
  Ash Resource: ContentField
  """
  use Ash.Resource,
    domain: Lotus.CMS.AshDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  # GraphQL 扩展暂时移除，避免类型名称冲突
  # extensions: [AshJsonApi.Resource, AshGraphql.Resource]

  postgres do
    table("content_fields")
    repo(Lotus.Repo)
  end

  json_api do
    type("content_field")

    routes do
      base("/content_fields")
      index(:read)
      post(:create)
      patch(:update)
      delete(:destroy)
    end
  end

  # GraphQL 配置暂时移除，避免类型名称冲突
  # graphql do
  #   type(:content_field)
  #
  #   queries do
  #     list(:content_fields, :read)
  #   end
  #
  #   mutations do
  #     create(:create_content_field, :create)
  #     update(:update_content_field, :update)
  #     destroy(:destroy_content_field, :destroy)
  #   end
  # end

  attributes do
    uuid_primary_key(:id)
    attribute(:content_type_id, :uuid, public?: true)
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:kind, :string, allow_nil?: false, public?: true)
    attribute(:required, :boolean, default: false, public?: true)
    attribute(:unique, :boolean, default: false, public?: true)
    attribute(:default, :string, public?: true)
    attribute(:order, :integer, default: 0, public?: true)
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
      accept([:content_type_id, :name, :kind, :required, :unique, :default, :order, :options])
    end

    update :update do
      accept([:name, :kind, :required, :unique, :default, :order, :options])
    end
  end

  policies do
    policy always() do
      authorize_if(always())
    end
  end
end
