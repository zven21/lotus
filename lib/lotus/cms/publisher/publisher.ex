defmodule Lotus.CMS.Publisher do
  @moduledoc """
  Publisher: Generates strongly-typed resources and stable APIs from configuration files.

  ## Architecture

  Publisher uses a modular design, splitting different functionalities into independent generator modules:

  - `Publisher.Config` - Configuration loading and validation
  - `Publisher.Generators.Resource` - Resource structure generation
  - `Publisher.Generators.Attributes` - Attribute generation
  - `Publisher.Generators.Relationships` - Relationship generation
  - `Publisher.Generators.Actions` - Action generation
  - `Publisher.Generators.Policies` - Policy generation
  - `Publisher.Generators.Search` - Search functionality generation
  - `Publisher.Generators.Validations` - Validation logic generation
  - `Publisher.Generators.Hooks` - Lifecycle hook generation
  - `Publisher.Generators.Audit` - Audit log generation
  - `Publisher.Generators.GraphQL` - GraphQL type generation
  - `Publisher.Generators.Migrations` - Database migration generation

  ## Workflow

  1. Load and validate configuration files
  2. Generate Ash Resource code
  3. Generate GraphQL type definitions
  4. Generate database migrations (optional)
  5. Register to Domain
  6. Compile and test

  ## Supported Features

  ### Implemented
  - ✅ Basic field definitions
  - ✅ JSON:API routes
  - ✅ GraphQL Schema
  - ✅ Basic CRUD operations

  ### Planned (TODO)
  - ⏳ Relationship definitions (oneToMany, manyToOne, manyToMany)
  - ⏳ Search and filtering
  - ⏳ Permission control
  - ⏳ Field validation
  - ⏳ Audit logging
  - ⏳ Lifecycle hooks
  - ⏳ Versioning
  - ⏳ Internationalization
  - ⏳ Media support
  - ⏳ Workflow
  """

  require Lotus.DynamicModule
  require Ash.Query

  alias Ash.Query
  alias Ecto.Migrator
  alias Lotus.CMS.AshDomain
  alias Lotus.CMS.Ash.{ContentType, ContentField, ContentRelation}
  alias Lotus.CMS.Publisher.Config
  alias Lotus.CMS.Publisher.Generators.{Resource, GraphQL, Migrations}
  alias Lotus.CMS.Publisher.{MigrationOrchestrator, MigrationWriter}
  alias Lotus.CMS.Publisher.Snapshot
  import Ash.Expr
  alias Lotus.Repo
  alias Lotus.CMS.ContentType, as: EctoContentType

  @generated_root "lib/lotus/generated"

  # ----- Published Config Helpers -----
  def get_published_config(slug) do
    case Repo.get_by(EctoContentType, slug: slug) do
      %EctoContentType{options: opts} when is_map(opts) ->
        case Map.get(opts, "published_config") do
          nil -> {:error, :not_found}
          cfg -> {:ok, cfg}
        end

      nil ->
        {:error, :not_found}
    end
  end

  def set_published_config(slug, config) when is_map(config) do
    case Repo.get_by(EctoContentType, slug: slug) do
      %EctoContentType{} = rec ->
        new_opts = Map.put(rec.options || %{}, "published_config", config)
        changeset = EctoContentType.changeset(rec, %{options: new_opts})

        case Repo.update(changeset) do
          {:ok, _} -> :ok
          {:error, e} -> {:error, e}
        end

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  发布全部内容类型。
  """
  def publish_all(opts \\ []) do
    ensure_placeholders()
    types = ContentType |> Query.new() |> Ash.read!(domain: AshDomain)
    modules = Enum.map(types, &publish_type(&1, opts))
    write_generated_domain(Enum.filter(modules, & &1))
  end

  @doc """
  从 priv/cms/*.json 读取 Manifest 发布。

  Manifest 基本格式：
    {
      "slug": "article",
      "name": "Article",
      "description": "...",
      "options": { }
    }
  """
  def publish_from_manifests(opts \\ []) do
    ensure_placeholders()
    cms_dir = Path.expand("priv/cms", Application.app_dir(:lotus, "../"))
    File.mkdir_p!(cms_dir)

    manifests =
      cms_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.map(&Path.join(cms_dir, &1))

    modules =
      for path <- manifests do
        with {:ok, bin} <- File.read(path),
             {:ok, %{"slug" => slug} = _json} <- Jason.decode(bin) do
          ensure_content_type!(slug)

          case ContentType
               |> Query.for_read(:by_slug, %{slug: slug})
               |> Ash.read_one!(domain: AshDomain) do
            nil -> nil
            type -> publish_type(type, opts)
          end
        else
          _ -> nil
        end
      end

    write_generated_domain(Enum.filter(modules, & &1))
  end

  @doc """
  Publish a content type with the specified slug.
  """
  def publish_slug(slug, opts \\ []) when is_binary(slug) do
    # Use config file channel to avoid old entries logic
    publish_slug_from_config(slug, opts)
  end

  @doc """
  Publish only the specified slug (loaded from config file).

  Options inherit from publish_from_config_files and support:
    * :directory - Config directory, default priv/cms/config
    * :generate_migrations - Default true
    * :validate - Default true
  """
  def publish_slug_from_config(slug, opts \\ []) when is_binary(slug) do
    ensure_placeholders()

    default_config_dir = Path.join([File.cwd!(), "priv", "cms", "config"])
    config_dir = Keyword.get(opts, :directory, default_config_dir)
    validate_config = Keyword.get(opts, :validate, true)
    generate_migrations = Keyword.get(opts, :generate_migrations, true)

    path_json = Path.join(config_dir, slug <> ".json")
    path_yaml = Path.join(config_dir, slug <> ".yaml")
    path_yml = Path.join(config_dir, slug <> ".yml")

    path =
      cond do
        File.exists?(path_json) -> path_json
        File.exists?(path_yaml) -> path_yaml
        File.exists?(path_yml) -> path_yml
        true -> nil
      end

    if is_nil(path) do
      {:error, :config_not_found}
    else
      with {:ok, raw_config} <- Config.load_file(path),
           validated_config <-
             if(validate_config,
               do:
                 case Config.validate(raw_config) do
                   {:ok, c} -> c
                   {:error, r} -> throw({:invalid, r})
                 end,
               else: raw_config
             ),
           normalized_config <- Config.normalize(validated_config),
           %{"slug" => ^slug} = normalized_config,
           type_id <- ensure_content_type_id(slug),
           _ <-
             if(generate_migrations,
               do:
                 case Migrations.write_migration_file(slug, normalized_config) do
                   {:ok, _} -> :ok
                   {:error, :file_exists} -> :ok
                   other -> other
                 end,
               else: :ok
             ),
           mod <- publish_type_with_config(slug, type_id, normalized_config, opts) do
        write_generated_domain([mod])
        GraphQL.write_types_aggregator()
        {:ok, mod}
      else
        {:invalid, reason} -> {:error, {:invalid_config, reason}}
        {:error, reason} -> {:error, reason}
        other -> other
      end
    end
  end

  @doc """
  Read and publish content types from config file directory (supports JSON and YAML formats).

  ## Options

    * `:directory` - Config file directory (default: `priv/cms/config`)
    * `:generate_migrations` - Whether to generate migration files (default: `false`)
    * `:validate` - Whether to validate config (default: `true`)
    * `:save_config_snapshot` - Whether to generate JSON config snapshot (default: `false`)

  ## Config File Format

  See `priv/cms/config/article_complex_example.json` for a complete configuration example.
  """
  def publish_from_config_files(opts \\ []) do
    ensure_placeholders()

    default_config_dir = Path.join([File.cwd!(), "priv", "cms", "config"])
    config_dir = Keyword.get(opts, :directory, default_config_dir)
    validate_config = Keyword.get(opts, :validate, true)
    generate_migrations = Keyword.get(opts, :generate_migrations, true)

    only =
      case Keyword.get(opts, :only, nil) do
        nil -> nil
        slug when is_binary(slug) -> MapSet.new([slug])
        slugs when is_list(slugs) -> MapSet.new(slugs)
      end

    save_config_snapshot = Keyword.get(opts, :save_config_snapshot, false)

    File.mkdir_p!(config_dir)

    config_files =
      config_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, [".json", ".yaml", ".yml"]))
      |> Enum.map(&Path.join(config_dir, &1))

    IO.puts("📂 Config directory: #{config_dir}")
    IO.puts("📄 Found #{length(config_files)} config files")

    modules =
      for path <- config_files do
        IO.puts("📝 Processing file: #{path}")

        case Config.load_file(path) do
          {:ok, raw_config} ->
            # Validate config (if enabled)
            validated_config =
              if validate_config do
                case Config.validate(raw_config) do
                  {:ok, config} ->
                    config

                  {:error, reason} ->
                    IO.puts("❌ Config validation failed: #{inspect(reason)}")
                    nil
                end
              else
                raw_config
              end

            if validated_config != nil do
              normalized_config = Config.normalize(validated_config)

              case normalized_config do
                %{"slug" => slug} ->
                  if only && not MapSet.member?(only, slug), do: throw(:skip)
                  IO.puts("✅ Config loaded successfully, slug: #{slug}")

                  # Ensure content type exists in database
                  type_id = ensure_content_type_id(slug)

                  IO.puts("🚀 Publishing type: #{slug}")

                  # Generate resource code
                  result = publish_type_with_config(slug, type_id, normalized_config, opts)

                  # Generate migration file (if enabled)
                  if generate_migrations do
                    IO.puts("📦 Generating migration file...")

                    case Migrations.write_migration_file(slug, normalized_config) do
                      {:ok, filepath} ->
                        IO.puts("  ✅ Migration file generated: #{filepath}")

                      {:error, :file_exists} ->
                        IO.puts("  ⚠️  Migration file already exists, skipping")

                      {:error, reason} ->
                        IO.puts("  ❌ Migration file generation failed: #{inspect(reason)}")
                    end
                  end

                  # Generate JSON config snapshot (if enabled)
                  if save_config_snapshot do
                    case save_config_snapshot_file(slug, normalized_config, config_dir) do
                      {:ok, filepath} ->
                        IO.puts("  ✅ Config snapshot saved: #{filepath}")

                      {:error, reason} ->
                        IO.puts("  ⚠️  Config snapshot save failed: #{inspect(reason)}")
                    end
                  end

                  IO.puts("✅ Publishing completed: #{slug}")
                  result

                _ ->
                  IO.puts("❌ Config is missing slug field")
                  nil
              end
            else
              nil
            end

          {:error, reason} ->
            IO.puts("❌ Config loading failed: #{inspect(reason)}")
            nil
        end
      end

    write_generated_domain(Enum.filter(modules, & &1))

    # Ensure GraphQL type aggregator includes all generated types
    # Even though each type has been called during publishing, ensure final state consistency here
    GraphQL.write_types_aggregator()

    :ok
  end

  # Removed: unused load_config_file/1

  # Ensure content type ID (get from database or create)
  defp ensure_content_type_id(slug) do
    try do
      ensure_content_type!(slug)

      case ContentType
           |> Query.for_read(:by_slug, %{slug: slug})
           |> Ash.read_one!(domain: AshDomain) do
        nil -> "00000000-0000-0000-0000-000000000000"
        found -> found.id
      end
    rescue
      _ -> "00000000-0000-0000-0000-000000000000"
    end
  end

  # Publish using config (new unified entry point)
  defp publish_type_with_config(slug, type_id, config, opts) do
    fields = Map.get(config, "fields", [])

    publish_resource(slug, type_id, config, opts)
    publish_graphql_types(slug, fields, opts)

    # Return module name
    slug_pascal = Recase.to_pascal(slug)
    String.to_atom("Elixir.Lotus.CMS.Generated.#{slug_pascal}")
  end

  # Generate resource code
  defp publish_resource(slug, type_id, config, _opts) do
    slug_pascal = Recase.to_pascal(slug)
    slug_camel = Recase.to_camel(slug)
    mod_name = "Lotus.CMS.Generated.#{slug_pascal}"

    # Generate complete resource code using Resource generator
    {preamble_ast, contents_ast} = Resource.generate(slug, type_id, config)

    # Write generated resource file
    path = @generated_root

    Lotus.DynamicModule.gen(
      mod_name,
      preamble_ast,
      contents_ast,
      doc: "Generated resource for content type #{slug}",
      path: path,
      filename: "resources/#{slug_camel}.ex",
      create: true
    )

    # Wait for file write to complete
    Process.sleep(100)
  end

  # Generate GraphQL type definitions
  defp publish_graphql_types(slug, fields, opts) do
    GraphQL.publish_types(slug, fields, opts)
  end

  # Build resource content (placeholder, implementation removed)
  # end

  # Handle empty field list or non-list parameter cases
  # defp build_resource_contents(slug, type_id, fields) when not is_list(fields) do
  #   build_resource_contents(slug, type_id, [])
  # end

  # Handle empty field list case (placeholder, no implementation)
  # defp build_resource_contents(slug, type_id, _fields) when length([]) == 0 do
  # end

  # Removed: legacy attribute generation demo code

  # Map field type to Ash type
  # Removed: unused map_field_kind_to_ash_type/2

  # Removed: legacy constraint generation demo code

  defp publish_type(%ContentType{} = type, _opts) do
    slug = type.slug
    slug_pascal = Recase.to_pascal(slug)
    slug_camel = Recase.to_camel(slug)
    mod_name = "Lotus.CMS.Generated.#{slug_pascal}"

    # Pre-calculate values needed for GraphQL naming
    plural = Inflex.pluralize(slug)
    pascal = Macro.camelize(slug)

    preamble =
      quote do
        use Ash.Resource,
          domain: Lotus.CMS.Generated,
          data_layer: AshPostgres.DataLayer,
          authorizers: [Ash.Policy.Authorizer],
          extensions: [AshJsonApi.Resource, AshGraphql.Resource],
          primary_read_warning?: false

        postgres do
          table("entries")
          repo(Lotus.Repo)
        end

        json_api do
          type(unquote(slug))

          routes do
            base("/" <> unquote(slug))
            index(:read)
            get(:read)
            post(:create)
            patch(:update)
            delete(:destroy)
          end
        end

        graphql do
          type(unquote(String.to_atom("generated_" <> slug)))

          attribute_types(
            data: :json,
            locale: :string
          )

          show_fields([:id, :locale, :data])
          attribute_input_types(data: :json_string)

          queries do
            list(unquote(String.to_atom(plural)), :read)
            get(unquote(String.to_atom(slug)), :read)
          end

          mutations do
            create(unquote(String.to_atom("create" <> pascal)), :create)
            update(unquote(String.to_atom("update" <> pascal)), :update)
            destroy(unquote(String.to_atom("delete" <> pascal)), :destroy)
          end
        end
      end

    contents =
      quote do
        attributes do
          uuid_primary_key(:id)
          attribute(:content_type_id, :uuid, public?: true)
          attribute(:locale, :string, default: "en", public?: true)
          attribute(:data, :map, default: %{}, public?: true)
          attribute(:owner_id, :uuid, public?: true)

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

        actions do
          defaults([:destroy])

          read :read do
            primary?(true)
            filter(expr(content_type.slug == unquote(slug)))
          end

          create :create do
            primary?(true)
            accept([:locale, :data, :owner_id])
            change(set_attribute(:content_type_id, unquote(type.id)))
          end

          update :update do
            primary?(true)
            accept([:locale, :data, :owner_id])
            require_atomic?(false)
          end
        end

        policies do
          policy always() do
            authorize_if(always())
          end
        end
      end

    path = @generated_root

    Lotus.DynamicModule.gen(
      mod_name,
      preamble,
      contents,
      doc: "Generated resource for content type #{slug}",
      path: path,
      filename: "resources/#{slug_camel}.ex"
    )

    # Don't generate specific data object type when no field definitions

    String.to_atom("Elixir." <> mod_name)
  end

  # Delegate to GraphQL generator
  def write_graphql_types_aggregator do
    GraphQL.write_types_aggregator()
  end

  @doc """
  Complete workflow: build config from database, generate migrations, run migrations, and publish resources.

  ## Options

    * `:slugs` - List of content type slugs to publish (default: read all from database)
    * `:run_migrations` - Whether to run migrations (default: `true`)
    * `:skip_migrations` - Whether to skip generating migration files (default: `false`)

  ## Workflow

  1. Build config from database
  2. Generate migration files
  3. Run `mix ecto.migrate`
  4. Generate Ash Resource files (author.ex, article.ex)
  5. Update Generated Domain

  ## Examples

      # Publish all content types
      Publisher.publish_from_database_with_migrations()

      # Publish specified content types
      Publisher.publish_from_database_with_migrations(slugs: ["author", "article"])

      # Only generate migrations but don't run them
      Publisher.publish_from_database_with_migrations(run_migrations: false)
  """
  def publish_from_database_with_migrations(opts \\ []) do
    ensure_placeholders()

    slugs = Keyword.get(opts, :slugs, nil)
    run_migrations = Keyword.get(opts, :run_migrations, true)
    skip_migrations = Keyword.get(opts, :skip_migrations, false)

    # Get list of slugs to publish
    slugs_to_publish =
      if slugs do
        # Expand: include referenced target types to ensure reverse relationships are created
        expand_slugs_with_targets(slugs)
      else
        # Read all content types from database
        ContentType
        |> Query.new()
        |> Ash.read!(domain: AshDomain)
        |> Enum.map(& &1.slug)
      end

    IO.puts("🚀 Starting publishing process, #{length(slugs_to_publish)} content type(s)")
    IO.puts("   Type list: #{Enum.join(slugs_to_publish, ", ")}")

    results =
      Enum.map(slugs_to_publish, fn slug ->
        IO.puts("\n📦 Processing content type: #{slug}")

        # 1. Build config from database
        case build_config_from_database(slug) do
          {:ok, config} ->
            IO.puts("  ✅ Config build successful")

            # 2. Generate migration file (if not skipped)
            migration_result =
              if skip_migrations do
                {:ok, :skipped}
              else
                IO.puts("  📝 Generating migration file...")

                old_config =
                  case get_published_config(slug) do
                    {:ok, cfg} ->
                      Map.put(cfg, "published", true)

                    {:error, :not_found} ->
                      %{
                        "meta" => %{"version" => "0.0.0", "name" => slug, "slug" => slug},
                        "storage" => %{"table" => "cms_#{Inflex.pluralize(slug)}"},
                        "fields" => [],
                        "relationships" => [],
                        "published" => false
                      }

                    _ ->
                      %{
                        "fields" => [],
                        "relationships" => [],
                        "storage" => %{"table" => "cms_#{Inflex.pluralize(slug)}"},
                        "published" => false
                      }
                  end

                result = MigrationOrchestrator.build(old_config, config)

                migrations_dir = Path.join([File.cwd!(), "priv", "repo", "migrations"])

                case result.plan.operations do
                  [] ->
                    IO.puts("    ℹ️  No incremental changes, skipping migration generation")
                    {:ok, :no_changes}

                  _ ->
                    case MigrationWriter.write(migrations_dir, slug, result) do
                      {:ok, filepath} ->
                        IO.puts("    ✅ Migration file generated: #{Path.basename(filepath)}")
                        # Write published config
                        :ok = set_published_config(slug, config)
                        {:ok, filepath}

                      {:error, reason} ->
                        IO.puts("    ❌ Migration file generation failed: #{inspect(reason)}")
                        {:error, reason}
                    end
                end
              end

            # 3. Run migration (if enabled)
            migrate_result =
              if run_migrations and not skip_migrations do
                case migration_result do
                  {:error, _reason} ->
                    :skipped

                  _ ->
                    IO.puts("  🔄 Running database migration...")

                    case run_ecto_migrate() do
                      :ok ->
                        IO.puts("    ✅ Migration executed successfully")
                        :ok

                      {:error, reason} ->
                        IO.puts("    ❌ Migration execution failed: #{inspect(reason)}")
                        {:error, reason}
                    end
                end
              else
                :skipped
              end

            # 4. Generate resource file
            IO.puts("  📄 Generating resource file...")
            type_id = ensure_content_type_id(slug)
            module = publish_type_with_config(slug, type_id, config, opts)
            IO.puts("    ✅ Resource file generated: #{slug}.ex")

            {:ok, slug, module, migration_result, migrate_result}

          {:error, reason} ->
            IO.puts("  ❌ Config build failed: #{inspect(reason)}")
            {:error, slug, reason}
        end
      end)

    # 5. Update Generated Domain
    successful_modules =
      results
      |> Enum.filter(fn
        {:ok, _slug, module, _migration, _migrate} -> module != nil
        _ -> false
      end)
      |> Enum.map(fn {:ok, _slug, module, _migration, _migrate} -> module end)

    if length(successful_modules) > 0 do
      IO.puts("\n🔧 Updating Generated Domain...")
      write_generated_domain(successful_modules)
      IO.puts("  ✅ Domain update completed")
    end

    # Ensure GraphQL type aggregator
    GraphQL.write_types_aggregator()

    IO.puts("\n✅ Publishing process completed!")
    {:ok, results}
  end

  defp expand_slugs_with_targets(slugs) do
    slugs_set = MapSet.new(slugs)

    # Find IDs of these types
    types =
      ContentType
      |> Query.new()
      |> Query.filter(expr(slug in ^slugs))
      |> Ash.read!(domain: AshDomain)

    type_ids = Enum.map(types, & &1.id)

    # Find target slugs of relationships defined by these types
    targets =
      ContentRelation
      |> Query.new()
      |> Query.filter(expr(content_type_id in ^type_ids))
      |> Ash.read!(domain: AshDomain)
      |> Enum.map(& &1.target)

    Enum.uniq(MapSet.to_list(MapSet.union(slugs_set, MapSet.new(targets))))
  end

  # Run mix ecto.migrate
  defp run_ecto_migrate do
    # Directly use Ecto.Migrator to run migrations in process
    repo = Lotus.Repo
    migrations_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])

    case Migrator.with_repo(repo, fn _ ->
           Migrator.run(repo, migrations_path, :up, all: true)
         end) do
      {:ok, _versions, _steps} -> :ok
      {:error, _, error} -> {:error, inspect(error)}
      error -> {:error, inspect(error)}
    end
  rescue
    e -> {:error, "Failed to run migration: #{inspect(e)}"}
  end

  @doc """
  Build configuration structure from database tables: content_types, content_fields, content_relations.

  Used to read content type definitions from database and convert to configuration format needed for publishing.
  """
  def build_config_from_database(slug) do
    # Find content type
    content_type =
      ContentType
      |> Query.for_read(:by_slug, %{slug: slug})
      |> Ash.read_one!(domain: AshDomain)

    if is_nil(content_type) do
      {:error, :not_found}
    else
      plural = Inflex.pluralize(slug)
      table = "cms_#{plural}"
      # Find fields
      fields =
        ContentField
        |> Query.new()
        |> Query.filter(expr(content_type_id == ^content_type.id))
        |> Query.sort(order: :asc)
        |> Ash.read!(domain: AshDomain)
        |> Enum.map(fn field ->
          %{
            "name" => field.name,
            "kind" => field.kind,
            "required" => field.required,
            "unique" => field.unique,
            "options" => field.options || %{},
            "default" => field.default
          }
        end)

      # Find relationships defined by current type (outbound)
      outbound_relations =
        ContentRelation
        |> Query.new()
        |> Query.filter(expr(content_type_id == ^content_type.id))
        |> Ash.read!(domain: AshDomain)
        |> Enum.map(fn rel ->
          %{
            "name" => rel.name,
            "type" => rel.type,
            "target" => rel.target,
            "foreign_key" => rel.foreign_key,
            "target_field" => rel.target_field,
            "on_delete" => rel.on_delete,
            "through" => rel.through,
            "options" => rel.options || %{}
          }
        end)

      inbound_relations =
        ContentRelation
        |> Query.new()
        |> Query.filter(expr(target == ^slug))
        |> Ash.read!(domain: AshDomain)
        |> Enum.flat_map(fn rel ->
          case rel.type do
            "manyToOne" ->
              source_type =
                ContentType
                |> Query.new()
                |> Query.filter(expr(id == ^rel.content_type_id))
                |> Ash.read_one!(domain: AshDomain)

              source_slug = source_type && source_type.slug
              backref_name = rel.target_field || source_slug <> "_" <> rel.name

              [
                %{
                  "name" => backref_name,
                  "type" => "oneToMany",
                  "target" => source_slug,
                  "foreign_key" => rel.foreign_key || rel.name <> "_id",
                  "target_field" => rel.name,
                  "on_delete" => rel.on_delete,
                  "through" => rel.through,
                  "options" => rel.options || %{}
                }
              ]

            _ ->
              []
          end
        end)

      relations =
        (outbound_relations ++ inbound_relations)
        |> Enum.reverse()
        |> Enum.uniq_by(& &1["name"])
        |> Enum.reverse()

      config = %{
        "slug" => slug,
        "name" => content_type.name,
        "description" => content_type.description,
        "options" => content_type.options || %{},
        "storage" => %{"table" => table},
        "fields" => fields,
        "relationships" => relations,
        "indexes" => []
      }

      {:ok, config}
    end
  end

  @doc """
  将配置保存为 JSON 配置文件快照。

  用于从数据库构建的配置或规范化后的配置保存为 JSON 文件，便于后续使用或版本控制。
  """
  def save_config_snapshot_file(slug, config, config_dir \\ nil) do
    config_dir =
      if config_dir do
        config_dir
      else
        Path.join([File.cwd!(), "priv", "cms", "config"])
      end

    File.mkdir_p!(config_dir)
    filepath = Path.join(config_dir, "#{slug}.json")

    case Jason.encode(config, pretty: true) do
      {:ok, json_content} ->
        case File.write(filepath, json_content) do
          :ok -> {:ok, filepath}
          error -> error
        end

      error ->
        error
    end
  end

  defp ensure_content_type!(slug) do
    case ContentType
         |> Query.for_read(:by_slug, %{slug: slug})
         |> Ash.read_one!(domain: AshDomain) do
      nil ->
        Ash.create!(ContentType, %{slug: slug, name: Recase.to_title(slug)}, domain: AshDomain)

      _ ->
        :ok
    end
  end

  defp write_generated_domain(resource_modules) do
    # Incremental merge: read existing resources from Generated Domain and merge with newly generated resources, deduplicating
    existing = existing_generated_resources()

    modules =
      (existing ++ resource_modules)
      |> Enum.uniq()

    preamble =
      quote do
        use Ash.Domain,
          extensions: [AshJsonApi.Domain, AshGraphql.Domain]
      end

    resources_ast =
      for mod <- modules do
        quote do
          resource(unquote(mod))
        end
      end

    contents =
      quote do
        resources do
          (unquote_splicing(resources_ast))
        end
      end

    Lotus.DynamicModule.gen(
      "Lotus.CMS.Generated",
      preamble,
      contents,
      doc: "Generated domain aggregation for published content types",
      path: @generated_root,
      filename: "generated.ex"
    )

    # Temporarily don't add json_api config to avoid compilation errors
    # generated_file = Path.join(@generated_root, "Lotus.CMS.Generated.ex")
    # add_json_api_to_domain_file(generated_file)

    # TODO: Dynamic Schema generation temporarily commented out to avoid conflicts with main Schema
    # In the future, can automatically reference Generated domain in main Schema

    # schema_preamble =
    #   quote do
    #     use Absinthe.Schema
    #     use AshGraphql, domains: [Lotus.CMS.AshDomain, Lotus.CMS.Generated]

    #     query do
    #     end

    #     mutation do
    #     end
    #   end

    # Lotus.DynamicModule.gen(
    #   "LotusWeb.DynamicSchema",
    #   schema_preamble,
    #   quote do
    #   end,
    #   doc: "Dynamic Absinthe schema including Generated domain",
    #   path: "lib/lotus_web"
    # )
  end

  defp existing_generated_resources do
    path = Path.join(@generated_root, "generated.ex")

    if File.exists?(path) do
      case File.read(path) do
        {:ok, bin} ->
          # 粗略解析：提取 resource(ModuleName) 行，兼容不同格式与空格
          bin
          |> String.split(["\n", "\r\n"], trim: true)
          |> Enum.filter(&String.contains?(&1, "resource("))
          |> Enum.map(fn line ->
            case Regex.run(~r/resource\(([^\)]+)\)/, line) do
              [_, mod_str] ->
                mod_str
                |> String.trim()
                |> String.trim_trailing(",")
                |> String.replace_prefix("Elixir.", "")
                |> then(&("Elixir." <> &1))
                |> String.to_atom()

              _ ->
                nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        _ ->
          []
      end
    else
      []
    end
  end

  # 占位文件确保：generated.ex、GraphQL GeneratedTypes 和 DataFieldResolver
  def ensure_placeholders do
    # Domain placeholder
    domain_file = Path.join(@generated_root, "generated.ex")

    if not File.exists?(domain_file) do
      Lotus.DynamicModule.gen(
        "Lotus.CMS.Generated",
        quote do
          use Ash.Domain, extensions: [AshJsonApi.Domain, AshGraphql.Domain]
        end,
        quote do
          resources do
          end
        end,
        doc: "Generated domain placeholder",
        path: @generated_root,
        filename: "generated.ex"
      )
    end
  end
end
