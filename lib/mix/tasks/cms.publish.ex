defmodule Mix.Tasks.Cms.Publish do
  use Mix.Task
  @shortdoc "发布内容类型为强类型 API（全部或按 slug）"

  @moduledoc """
  发布所有或指定 slug 的内容类型，生成强类型资源并聚合到 `Lotus.CMS.Generated`。

      mix cms.publish                    # 发布全部（从数据库）
      mix cms.publish slug=article       # 发布指定 slug
      mix cms.publish --from-config      # 从配置文件发布（参考 Strapi）
  """

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case parse_args(args) do
      {:config} ->
        Lotus.CMS.Publisher.publish_from_config_files()
        Mix.shell().info([:green, "✅ Published from configuration files."])

      {:all} ->
        Lotus.CMS.Publisher.publish_all()
        Mix.shell().info([:green, "✅ Published all content types from database."])

      {:one, slug} ->
        Lotus.CMS.Publisher.publish_slug(slug)
        Mix.shell().info([:green, "✅ Published #{slug}."])
    end

    Mix.shell().info([:green, "✅ Publish done."])
  end

  defp parse_args(args) do
    cond do
      "--from-config" in args or "-c" in args ->
        {:config}

      Enum.any?(args, &String.starts_with?(&1, "slug=")) ->
        slug_arg = Enum.find(args, &String.starts_with?(&1, "slug="))
        "slug=" <> slug = slug_arg
        {:one, slug}

      true ->
        {:all}
    end
  end
end
