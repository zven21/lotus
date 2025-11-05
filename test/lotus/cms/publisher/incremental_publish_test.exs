defmodule Lotus.CMS.Publisher.IncrementalPublishTest do
  use Lotus.DataCase, async: false

  import Ecto.Query
  require Ash.Query
  alias Lotus.CMS.Ash.{ContentType, ContentField}
  alias Lotus.CMS.AshDomain
  alias Lotus.CMS.Publisher

  test "first publish creates table; adding field produces alter migration and updates published_config" do
    original_cwd = File.cwd!()
    tmp = Path.join(System.tmp_dir!(), "lotus_inc_" <> Ecto.UUID.generate())

    try do
      File.mkdir_p!(tmp)
      File.cd!(tmp)

      File.mkdir_p!(Path.join([tmp, "priv", "repo", "migrations"]))

      {:ok, _author} =
        Ash.create(ContentType, %{slug: "author", name: "Author"}, domain: AshDomain)

      {:ok, results} =
        Publisher.publish_from_database_with_migrations(slugs: ["author"], run_migrations: false)

      assert Enum.any?(results, fn
               {:ok, "author", _mod, {:ok, :no_changes}, _} ->
                 true

               {:ok, "author", _mod, {:ok, :exists}, _} ->
                 true

               {:ok, "author", _mod, {:ok, path}, _} when is_binary(path) ->
                 String.contains?(path, "author_change.exs")

               _ ->
                 false
             end)

      migs = Path.join([tmp, "priv", "repo", "migrations"]) |> File.ls!() |> Enum.sort()
      assert length(migs) >= 1
      first = List.last(migs)
      content1 = File.read!(Path.join([tmp, "priv", "repo", "migrations", first]))
      assert content1 =~ "defmodule Lotus.Repo.Migrations.CreateCmsAuthors"
      assert content1 =~ "create table(:cms_authors"

      # add field
      {:ok, type_rec} =
        ContentType
        |> Ash.Query.for_read(:by_slug, %{slug: "author"})
        |> Ash.read_one(domain: AshDomain)

      {:ok, _f} =
        Ash.create(
          ContentField,
          %{content_type_id: type_rec.id, name: "nickname", kind: "string"},
          domain: AshDomain
        )

      {:ok, _} =
        Publisher.publish_from_database_with_migrations(slugs: ["author"], run_migrations: false)

      migs2 = Path.join([tmp, "priv", "repo", "migrations"]) |> File.ls!() |> Enum.sort()
      assert length(migs2) >= 2
      second = List.last(migs2)
      content2 = File.read!(Path.join([tmp, "priv", "repo", "migrations", second]))
      assert content2 =~ "defmodule Lotus.Repo.Migrations.AlterCmsAuthors"
      assert content2 =~ "alter table(:cms_authors)"
      assert content2 =~ "add :nickname, :string"

      {:ok, type_after} =
        ContentType
        |> Ash.Query.for_read(:by_slug, %{slug: "author"})
        |> Ash.read_one(domain: AshDomain)

      assert is_map(type_after.options)
      pub_cfg = Map.get(type_after.options, "published_config")
      assert is_map(pub_cfg)
      assert Enum.any?(pub_cfg["fields"] || [], fn f -> f["name"] == "nickname" end)
    after
      File.cd!(original_cwd)
      File.rm_rf(tmp)
    end
  end
end
