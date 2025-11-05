defmodule Mix.Tasks.Cms.EnsurePlaceholders do
  @moduledoc """
  Ensures CMS placeholder files exist before compilation.

  This task is automatically run before compilation to ensure all required
  placeholder files exist. This is necessary because some modules (like
  LotusWeb.Schema) reference these files at compile time.

  Usage: mix cms.ensure_placeholders
  """

  use Mix.Task

  @shortdoc "Ensures CMS placeholder files exist (auto-run before compile)"

  def run(_args) do
    # 确保在正确的目录下
    Mix.shell().info("📦 Ensuring CMS placeholders...")

    generated_root = "lib/lotus/generated"

    # 1. Domain placeholder
    domain_file = Path.join(generated_root, "generated.ex")

    unless File.exists?(domain_file) do
      File.mkdir_p!(generated_root)

      domain_content = """
      defmodule Lotus.CMS.Generated do
        @moduledoc "Generated domain placeholder"
        use Ash.Domain, extensions: [AshJsonApi.Domain, AshGraphql.Domain]
        
        resources do
        end
      end
      """

      File.write!(domain_file, domain_content)
      Mix.shell().info([:green, "✅ Created domain placeholder: #{domain_file}"])
    else
      Mix.shell().info("Domain placeholder already exists")
    end

    # 2. GraphQL types placeholder
    gql_dir = Path.join(generated_root, "graphql")
    gql_file = Path.join(gql_dir, "generated_types.ex")

    unless File.exists?(gql_file) do
      File.mkdir_p!(gql_dir)

      gql_content = """
      defmodule LotusWeb.GraphQL.GeneratedTypes do
        @moduledoc "Aggregated generated GraphQL data object types (placeholder)"
        use Absinthe.Schema.Notation
        
        # Placeholder: no generated types yet
      end
      """

      File.write!(gql_file, gql_content)
      Mix.shell().info([:green, "✅ Created GraphQL types placeholder: #{gql_file}"])
    else
      Mix.shell().info("GraphQL types placeholder already exists")
    end

    # 3. DataFieldResolver placeholder
    resolver_file = Path.join(gql_dir, "data_field_resolver.ex")

    unless File.exists?(resolver_file) do
      template_file =
        Path.join(["lib", "lotus", "cms", "publisher", "templates", "data_field_resolver.ex.eex"])

      if File.exists?(template_file) do
        app_name = Mix.Project.config()[:app]
        app_module = app_name |> Atom.to_string() |> Recase.to_pascal()
        web_module = "#{app_module}Web"

        template_content =
          EEx.eval_file(template_file, app_module: app_module, web_module: web_module)

        File.write!(resolver_file, template_content)
        Mix.shell().info([:green, "✅ Created DataFieldResolver placeholder: #{resolver_file}"])
      else
        Mix.shell().warning("⚠️  Template file not found: #{template_file}")
      end
    else
      Mix.shell().info("DataFieldResolver placeholder already exists")
    end
  end
end
