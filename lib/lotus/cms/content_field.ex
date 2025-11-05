defmodule Lotus.CMS.ContentField do
  @moduledoc """
  内容字段模型（Content Field）
  用于定义每个内容类型的字段结构
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Lotus.CMS.ContentType

  @primary_key {:id, :binary_id, autogenerate: false}
  @derive {Phoenix.Param, key: :id}

  @field_kinds ~w(string text integer decimal boolean date datetime enum json relation media)

  schema "content_fields" do
    field :name, :string
    field :kind, :string
    field :required, :boolean, default: false
    field :unique, :boolean, default: false
    field :default, :string
    field :order, :integer, default: 0
    field :options, :map, default: %{}

    belongs_to :content_type, ContentType, type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(content_field, attrs) do
    content_field
    |> cast(attrs, [:name, :kind, :required, :unique, :default, :order, :options])
    |> validate_required([:name, :kind])
    |> validate_inclusion(:kind, @field_kinds)
    |> validate_format(:name, ~r/^[a-z][a-z0-9_]*$/,
      message: "must be snake_case and start with lowercase letter"
    )
    |> unique_constraint([:content_type_id, :name])
  end
end
