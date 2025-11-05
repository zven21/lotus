# Seeds 主文件
#
# 这个文件包含三个主要模块：
# 1. Seeds.Content - 创建和管理 content_types, content_fields, content_relations
# 2. Seeds.Publisher - 执行发布流程（从数据库构建配置、生成迁移、发布资源）
# 3. Seeds.MockData - 创建 author 和 article 的模拟数据
#
# 使用方式：取消注释相应的函数调用来执行对应的步骤

# ============================================================================
# 1. Content 操作模块：创建内容类型元数据
# ============================================================================

defmodule Seeds.Content do
  alias Lotus.CMS.AshDomain
  alias Lotus.CMS.Ash.{ContentType, ContentField, ContentRelation}
  require Ash.Query
  import Ash.Expr

  @moduledoc """
  创建和管理 content_types, content_fields, content_relations 的元数据
  """

  defmodule Helpers do
    alias Lotus.CMS.AshDomain
    alias Lotus.CMS.Ash.{ContentType, ContentField, ContentRelation}
    require Ash.Query
    import Ash.Expr

    def upsert_content_type!(slug, name, attrs \\ %{}) do
      case ContentType
           |> Ash.Query.for_read(:by_slug, %{slug: slug})
           |> Ash.read_one(domain: AshDomain) do
        {:ok, nil} ->
          params = Map.merge(%{slug: slug, name: name}, attrs)
          Ash.create!(ContentType, params, domain: AshDomain)

        {:ok, type} ->
          type

        {:error, _} ->
          params = Map.merge(%{slug: slug, name: name}, attrs)
          Ash.create!(ContentType, params, domain: AshDomain)
      end
    end

    def upsert_field!(%ContentType{id: type_id}, name, kind, opts \\ []) do
      case ContentField
           |> Ash.Query.new()
           |> Ash.Query.filter(expr(content_type_id == ^type_id and name == ^name))
           |> Ash.read_one(domain: AshDomain) do
        {:ok, nil} ->
          params =
            [
              content_type_id: type_id,
              name: name,
              kind: kind
            ]
            |> Keyword.merge(opts)
            |> Enum.into(%{})

          Ash.create!(ContentField, params, domain: AshDomain)

        {:ok, field} ->
          field

        {:error, _} ->
          params =
            [
              content_type_id: type_id,
              name: name,
              kind: kind
            ]
            |> Keyword.merge(opts)
            |> Enum.into(%{})

          Ash.create!(ContentField, params, domain: AshDomain)
      end
    end

    def upsert_relation!(%ContentType{id: type_id}, attrs) do
      name = Map.fetch!(attrs, :name)

      case ContentRelation
           |> Ash.Query.new()
           |> Ash.Query.filter(expr(content_type_id == ^type_id and name == ^name))
           |> Ash.read_one(domain: AshDomain) do
        {:ok, nil} ->
          Ash.create!(
            ContentRelation,
            Map.merge(%{content_type_id: type_id}, attrs),
            domain: AshDomain
          )

        {:ok, rel} ->
          rel

        {:error, _} ->
          Ash.create!(
            ContentRelation,
            Map.merge(%{content_type_id: type_id}, attrs),
            domain: AshDomain
          )
      end
    end
  end

  @doc """
  创建 author 和 article 的内容类型元数据
  """
  def create_author_and_article_types! do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("📋 Creating content type metadata (content_types, content_fields, content_relations)")
    IO.puts(String.duplicate("=", 60))

    # Seed: author 内容类型
    author = Helpers.upsert_content_type!("author", "Author")
    Helpers.upsert_field!(author, "name", "string", required: true, unique: true, order: 1)
    Helpers.upsert_field!(author, "email", "string", unique: true, order: 2)
    Helpers.upsert_field!(author, "bio", "text", order: 3)

    # Seed: article 内容类型
    article = Helpers.upsert_content_type!("article", "Article")
    Helpers.upsert_field!(article, "title", "string", required: true, order: 1)
    Helpers.upsert_field!(article, "body", "text", required: false, order: 2)

    # 关系：article -> author (manyToOne)
    Helpers.upsert_relation!(
      article,
      %{
        name: "author",
        type: "manyToOne",
        target: "author",
        foreign_key: "author_id",
        on_delete: "restrict",
        options: %{}
      }
    )

    Mix.shell().info([
      :green,
      "\n✅ Seeds applied: content_types, content_fields, content_relations (author/article)"
    ])

    {:ok, author, article}
  end
end

# ============================================================================
# 2. Publisher 模块：执行发布流程
# ============================================================================

defmodule Seeds.Publisher do
  alias Lotus.CMS.Publisher

  @moduledoc """
  执行发布流程：从数据库构建配置、生成迁移、执行迁移并发布资源
  """

  @doc """
  发布 author 和 article 内容类型

  ## Options

    * `:run_migrations` - 是否执行迁移（默认：`true`）
    * `:skip_migrations` - 是否跳过生成迁移文件（默认：`false`）
  """
  def publish_author_and_article(opts \\ []) do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("🚀 Executing full publishing process (publish_from_database_with_migrations)")
    IO.puts(String.duplicate("=", 60))

    run_migrations = Keyword.get(opts, :run_migrations, true)

    case Publisher.publish_from_database_with_migrations(
           slugs: ["author", "article"],
           run_migrations: run_migrations
         ) do
      {:ok, results} ->
        IO.puts("\n✅ Full publishing process executed successfully!")

        successful_count =
          results
          |> Enum.count(fn
            {:ok, _slug, _module, _migration, _migrate} -> true
            _ -> false
          end)

        IO.puts(
          "   Successfully published: #{successful_count}/#{length(results)} content type(s)"
        )

        # 等待数据库连接准备好
        Process.sleep(500)

        {:ok, results}

      {:error, reason} ->
        IO.puts([:red, "\n❌ Publishing process execution failed: #{inspect(reason)}"])
        {:error, reason}
    end
  end
end

# ============================================================================
# 3. MockData 模块：创建模拟数据
# ============================================================================

defmodule Seeds.MockData do
  alias Lotus.CMS.Generated.{Author, Article}
  require Ash.Query

  @moduledoc """
  创建 author 和 article 的模拟数据
  """

  @doc """
  创建 author 和 article 的模拟数据
  """
  def create_author_and_article_mock_data do
    # 删除现有的所有记录
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("🗑️  Cleaning existing data...")
    IO.puts(String.duplicate("=", 60))

    # 先删除 article（子表），再删除 author（父表），避免外键约束错误
    articles_to_delete =
      try do
        Ash.read!(Article, domain: Lotus.CMS.Generated)
      rescue
        _ ->
          IO.puts("  ℹ️  Article table does not exist or is not initialized, skipping deletion")
          []
      end

    if length(articles_to_delete) > 0 do
      IO.puts("  🗑️  Deleting #{length(articles_to_delete)} article(s)...")

      Enum.each(articles_to_delete, fn article ->
        try do
          Ash.destroy!(article, domain: Lotus.CMS.Generated)
        rescue
          e -> IO.puts("  ⚠️  Failed to delete article: #{inspect(e)}")
        end
      end)
    end

    authors_to_delete =
      try do
        Ash.read!(Author, domain: Lotus.CMS.Generated)
      rescue
        _ ->
          IO.puts("  ℹ️  Author table does not exist or is not initialized, skipping deletion")
          []
      end

    if length(authors_to_delete) > 0 do
      IO.puts("  🗑️  Deleting #{length(authors_to_delete)} author(s)...")

      Enum.each(authors_to_delete, fn author ->
        try do
          Ash.destroy!(author, domain: Lotus.CMS.Generated)
        rescue
          e -> IO.puts("  ⚠️  Failed to delete author: #{inspect(e)}")
        end
      end)
    end

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("📝 Creating mock data (author and article)")
    IO.puts(String.duplicate("=", 60))

    # 检查表是否存在（尝试查询，如果表不存在会报错）
    try do
      Article |> Ash.Query.new() |> Ash.read_one!(domain: Lotus.CMS.Generated)
      :ok
    rescue
      e ->
        error_str = inspect(e, pretty: true)

        if String.contains?(error_str, "does not exist") or
             String.contains?(error_str, "undefined_table") do
          Mix.shell().error([
            "\n❌ 错误：数据库表不存在！",
            "\n   请先执行步骤 2（Publisher）来创建表：",
            "\n   Seeds.Publisher.publish_author_and_article(run_migrations: true)",
            "\n"
          ])

          System.halt(1)
        else
          # 其他错误也继续执行，可能是空表
          :ok
        end
    end

    # 创建 Author 模拟数据（使用 upsert 逻辑，避免 unique 约束冲突）
    author_data = [
      %{
        name: "Ada Lovelace",
        email: "ada@example.com",
        bio:
          "Augusta Ada King, Countess of Lovelace, was an English mathematician and writer, chiefly known for her work on Charles Babbage's proposed mechanical general-purpose computer, the Analytical Engine."
      },
      %{
        name: "Alan Turing",
        email: "alan@example.com",
        bio:
          "Alan Mathison Turing was an English mathematician, computer scientist, logician, cryptanalyst, philosopher, and theoretical biologist."
      },
      %{
        name: "Grace Hopper",
        email: "grace@example.com",
        bio:
          "Grace Brewster Hopper was an American computer scientist and United States Navy rear admiral. She was one of the first programmers of the Harvard Mark I computer."
      },
      %{
        name: "Donald Knuth",
        email: "knuth@example.com",
        bio:
          "Donald Ervin Knuth is an American computer scientist, mathematician, and professor emeritus at Stanford University."
      }
    ]

    authors =
      Enum.map(author_data, fn attrs ->
        case Ash.create(Author, attrs, domain: Lotus.CMS.Generated) do
          {:ok, author} ->
            IO.puts("  ✅ Created author: #{author.name} (#{author.email})")
            author

          {:error, error} ->
            IO.puts("  ⚠️  Failed to create author #{attrs[:name]}: #{inspect(error)}")
            nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    # # 创建 Article 模拟数据
    if length(authors) > 0 do
      # 安全地获取作者 ID（避免索引越界）
      author_ids =
        authors
        # 只使用前 3 个作者
        |> Enum.take(3)
        |> Enum.map(& &1.id)

      articles =
        [
          %{
            title: "The History of Computing Pioneers",
            body:
              "Computing has been shaped by many brilliant minds throughout history. This article explores the contributions of early computing pioneers like Ada Lovelace, Alan Turing, and Grace Hopper.",
            author_id: Enum.at(author_ids, 0)
          },
          %{
            title: "Understanding Algorithms and Data Structures",
            body:
              "Algorithms and data structures form the foundation of computer science. In this comprehensive guide, we'll explore fundamental concepts that every programmer should know.",
            author_id: Enum.at(author_ids, 1) || Enum.at(author_ids, 0)
          },
          %{
            title: "The Art of Programming",
            body:
              "Programming is both a science and an art. Great programmers combine technical excellence with creative problem-solving. Let's dive into what makes code beautiful and maintainable.",
            author_id: Enum.at(author_ids, 2) || Enum.at(author_ids, 0)
          },
          %{
            title: "Modern Software Development Practices",
            body:
              "The software development landscape is constantly evolving. From agile methodologies to DevOps practices, this article covers modern approaches to building and deploying software.",
            author_id: Enum.at(author_ids, 0)
          },
          %{
            title: "Database Design Best Practices",
            body:
              "A well-designed database is crucial for application performance and maintainability. Learn about normalization, indexing strategies, and query optimization techniques.",
            author_id: Enum.at(author_ids, 1) || Enum.at(author_ids, 0)
          },
          %{
            title: "GraphQL vs REST API",
            body:
              "Both GraphQL and REST have their place in modern API design. This article compares their strengths, weaknesses, and when to use each approach.",
            author_id: Enum.at(author_ids, 2) || Enum.at(author_ids, 0)
          }
        ]
        # 过滤掉没有有效作者 ID 的文章
        |> Enum.filter(fn article -> article.author_id != nil end)

      created_articles =
        Enum.map(articles, fn attrs ->
          case Ash.create(Article, attrs, domain: Lotus.CMS.Generated) do
            {:ok, article} ->
              author_name =
                case Enum.find(authors, fn a -> a.id == attrs.author_id end) do
                  nil -> "Unknown Author"
                  author -> author.name
                end

              IO.puts("  ✅ Created article: #{article.title} (Author: #{author_name})")
              article

            {:error, error} ->
              IO.puts("  ⚠️  Failed to create article #{attrs[:title]}: #{inspect(error)}")
              IO.puts("     Error details: #{inspect(error, pretty: true)}")
              nil
          end
        end)
        |> Enum.filter(&(&1 != nil))

      IO.puts("\n📊 Data statistics:")
      IO.puts("   - Author count: #{length(authors)}")
      IO.puts("   - Article count: #{length(created_articles)}")
    else
      IO.puts("  ⚠️  Cannot create articles: no available authors")
    end

    Mix.shell().info([:green, "\n✅ 模拟数据创建完成！"])
  end
end

# ============================================================================
# 主执行流程（可根据需要取消注释相应的调用）
# ============================================================================

# 步骤 1: 创建内容类型元数据
# Seeds.Content.create_author_and_article_types!()

# 步骤 2: 执行发布流程（生成迁移、执行迁移、发布资源）
# Seeds.Publisher.publish_author_and_article(run_migrations: true)

# 步骤 3: 创建模拟数据（可选）
# Seeds.MockData.create_author_and_article_mock_data()
