defmodule Lotus.CMS.ContentType do
  @moduledoc """
  内容类型模型（Content Type）
  用于定义不同内容类型的结构（如：文章、页面、产品等）
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Lotus.CMS.ContentField

  @primary_key {:id, :binary_id, autogenerate: false}
  @derive {Phoenix.Param, key: :id}
  schema "content_types" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :options, :map, default: %{}

    has_many :fields, ContentField, foreign_key: :content_type_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(content_type, attrs) do
    content_type
    |> cast(attrs, [:slug, :name, :description, :options])
    |> validate_required([:slug, :name])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must be lowercase alphanumeric with hyphens"
    )
    |> unique_constraint(:slug)
  end
end
