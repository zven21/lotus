defmodule LotusWeb.CMS.EntryController do
  use LotusWeb, :controller

  alias Ash.Query

  def index(conn, %{"slug" => slug} = params) do
    case ensure_generated_resource(slug) do
      {:ok, mod} ->
        q = Query.new(mod)

        # 先做一个最小可用：限制 50 条；后续接入 Turbo 参数
        q = Query.limit(q, 50)

        entries = Ash.read!(q, domain: Lotus.CMS.Generated)

        render(conn, :index,
          slug: slug,
          module: mod,
          entries: entries,
          params: params
        )

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Type not published: #{slug}")
        |> redirect(to: ~p"/cms/builder")
    end
  end

  defp ensure_generated_resource(slug) do
    mod = Module.concat([Lotus, CMS, Generated, Recase.to_pascal(slug)])

    cond do
      ash_resource?(mod) ->
        {:ok, mod}

      true ->
        # 尝试即时发布该 slug
        _ = Lotus.CMS.Publisher.publish_from_database_with_migrations(slugs: [slug])
        if ash_resource?(mod), do: {:ok, mod}, else: {:error, :not_found}
    end
  end

  defp ash_resource?(mod) when is_atom(mod) do
    Code.ensure_loaded?(mod) and function_exported?(mod, :__ash_resource__, 0)
  end
end
