defmodule Lotus.CMS.PublisherSandboxTest do
  use ExUnit.Case, async: false

  require Lotus.DynamicModule

  alias Lotus.CMS.Publisher.Generators.Migrations
  alias Lotus.CMS.Publisher.Generators.Resource

  @author_config %{
    "fields" => [
      %{"name" => "name", "kind" => "string", "required" => true},
      %{"name" => "email", "kind" => "string", "required" => true, "unique" => true}
    ],
    "relationships" => []
  }

  @article_config %{
    "fields" => [
      %{"name" => "title", "kind" => "string", "required" => true},
      %{"name" => "body", "kind" => "text"}
    ],
    "relationships" => [
      %{
        "name" => "author",
        "type" => "manyToOne",
        "target" => "author",
        "foreign_key" => "author_id"
      }
    ]
  }

  test "generates migrations and resources inside sandbox without polluting project" do
    original_cwd = File.cwd!()
    tmp = Path.join(System.tmp_dir!(), "lotus_test_" <> Ecto.UUID.generate())

    try do
      File.mkdir_p!(tmp)
      File.cd!(tmp)

      # Ensure expected dirs exist under sandbox
      File.mkdir_p!(Path.join([tmp, "priv", "repo", "migrations"]))
      File.mkdir_p!(Path.join([tmp, "lib", "lotus", "generated"]))

      # 1) Write migrations into sandbox (cwd redirected)
      assert {:ok, path1} = Migrations.write_migration_file("author", @author_config)
      assert String.contains?(path1, Path.join(tmp, "priv/repo/migrations"))

      assert {:ok, path2} = Migrations.write_migration_file("article", @article_config)
      assert String.contains?(path2, Path.join(tmp, "priv/repo/migrations"))

      # Calling again should detect existence for the same table within the SAME sandbox
      assert {:error, :file_exists} = Migrations.write_migration_file("author", @author_config)

      # 2) Generate resource files into sandbox using DynamicModule with custom path
      #    We bypass the full publisher and directly use Resource.generate to avoid DB deps
      {preamble_a, contents_a} = Resource.generate("author", Ecto.UUID.generate(), @author_config)

      Lotus.DynamicModule.gen(
        "Lotus.CMS.Generated.Author",
        preamble_a,
        contents_a,
        doc: "Generated resource for author",
        path: Path.join(tmp, "lib/lotus/generated"),
        filename: "resources/Author.ex",
        create: true,
        output: false,
        format: false
      )

      assert File.exists?(Path.join(tmp, "lib/lotus/generated/resources/Author.ex"))

      {preamble_b, contents_b} =
        Resource.generate("article", Ecto.UUID.generate(), @article_config)

      Lotus.DynamicModule.gen(
        "Lotus.CMS.Generated.Article",
        preamble_b,
        contents_b,
        doc: "Generated resource for article",
        path: Path.join(tmp, "lib/lotus/generated"),
        filename: "resources/Article.ex",
        create: true,
        output: false,
        format: false
      )

      assert File.exists?(Path.join(tmp, "lib/lotus/generated/resources/Article.ex"))

      # Ensure project root not polluted (check specific migration files, not the directory)
      migrations_in_project =
        Path.join(original_cwd, "priv/repo/migrations")
        |> File.ls!()
        |> Enum.filter(fn fname ->
          String.contains?(fname, "create_cms_authors") or
            String.contains?(fname, "create_cms_articles")
        end)

      assert migrations_in_project == [],
             "Migration files should not be created in project root, but found: #{inspect(migrations_in_project)}"

      refute File.exists?(Path.join(original_cwd, "lib/lotus/generated/resources/Author.ex"))
      refute File.exists?(Path.join(original_cwd, "lib/lotus/generated/resources/Article.ex"))
    after
      File.cd!(original_cwd)
      # Best-effort cleanup
      File.rm_rf(tmp)
    end
  end
end
