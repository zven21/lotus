defmodule LotusWeb.CMSLive.Index do
  use LotusWeb, :live_view
  alias Lotus.CMS.AshDomain
  alias Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, types: list_types())}
  end

  defp list_types do
    Lotus.CMS.Ash.ContentType |> Query.new() |> Ash.read!(domain: AshDomain)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Content Manager</h1>
        <.link navigate={~p"/cms/builder"} class="btn btn-ghost">Open Builder</.link>
      </div>

      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Slug</th>
              <th>Name</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for t <- @types do %>
              <tr>
                <td class="font-mono">{t.slug}</td>
                <td>{t.name}</td>
                <td>
                  <.link navigate={~p"/cms/#{t.slug}/entries"} class="btn btn-sm btn-primary">
                    Manage Entries
                  </.link>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
