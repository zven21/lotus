defmodule Lotus.CMS.Publisher.ProjectionSyncTest do
  use Lotus.DataCase, async: false

  import Ecto.Query
  alias Lotus.CMS.Ash.{ContentType, ContentRelation}
  alias Lotus.CMS.Publisher.{ConfigSchema, ProjectionSync}
  alias Lotus.Repo

  @author_cfg %{
    "meta" => %{"version" => "1.0.0", "name" => "Author", "slug" => "author"},
    "storage" => %{"table" => "cms_authors"},
    "fields" => [
      %{"name" => "name", "type" => "string"},
      %{"name" => "email", "type" => "string", "unique" => true}
    ],
    "relationships" => []
  }

  @article_cfg %{
    "meta" => %{"version" => "1.0.0", "name" => "Article", "slug" => "article"},
    "storage" => %{"table" => "cms_articles"},
    "fields" => [
      %{"name" => "title", "type" => "string"},
      %{"name" => "body", "type" => "text"}
    ],
    "relationships" => [
      %{
        "name" => "author",
        "kind" => "belongs_to",
        "target" => %{"namespace" => "cms", "slug" => "author"}
      }
    ]
  }

  test "sync fields and relations from config" do
    {:ok, author} =
      Ash.create(ContentType, %{slug: "author", name: "Author"}, domain: Lotus.CMS.AshDomain)

    {:ok, article} =
      Ash.create(ContentType, %{slug: "article", name: "Article"}, domain: Lotus.CMS.AshDomain)

    assert {:ok, _} = ConfigSchema.validate(@author_cfg)
    assert {:ok, _} = ConfigSchema.validate(@article_cfg)

    assert :ok = ProjectionSync.sync(author.id, @author_cfg)
    assert :ok = ProjectionSync.sync(article.id, @article_cfg)

    # fields synced with order preserved
    author_fields =
      Repo.all(
        from f in Lotus.CMS.ContentField,
          where: f.content_type_id == ^author.id,
          order_by: f.order
      )

    assert Enum.map(author_fields, & &1.name) == ["name", "email"]
    # unique propagated
    assert Enum.find(author_fields, &(&1.name == "email")).unique == true

    # relation created with default foreign_key when missing
    rels =
      Ash.read!(ContentRelation, domain: Lotus.CMS.AshDomain)
      |> Enum.filter(&(&1.content_type_id == article.id))

    assert Enum.map(rels, & &1.name) == ["author"]
    assert Enum.at(rels, 0).foreign_key == "author_id"

    # update config: reorder and drop one field; drop relation
    updated_article = put_in(@article_cfg, ["fields"], [%{"name" => "body", "type" => "text"}])
    updated_article = put_in(updated_article, ["relationships"], [])

    assert :ok = ProjectionSync.sync(article.id, updated_article)

    article_fields =
      Repo.all(
        from f in Lotus.CMS.ContentField,
          where: f.content_type_id == ^article.id,
          order_by: f.order
      )

    assert Enum.map(article_fields, & &1.name) == ["body"]

    rels2 =
      Ash.read!(ContentRelation, domain: Lotus.CMS.AshDomain)
      |> Enum.filter(&(&1.content_type_id == article.id))

    assert rels2 == []
  end
end
