defmodule LotusWeb.CMSLive.BuilderIndex do
  use LotusWeb, :live_view
  alias Lotus.CMS.AshDomain
  alias Ash.Query
  require Ash.Query

  alias Lotus.CMS.Publisher.MigrationOrchestrator
  alias Lotus.CMS.Publisher.MigrationWriter

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       types: list_types(),
       form: %{slug: "", name: ""},
       flash_msg: nil,
       show_create_modal: false,
       show_publish_modal: false,
       publish_target: nil,
       publish_fields: [],
       publish_tab: "summary",
       preview_code: nil,
       plan_checksum: nil,
       config_checksum: nil,
       # add field modal
       show_add_field_modal: false,
       add_field_target: nil,
       add_field_form: %{name: "", type: "string"},
       # view config modal
       show_config_modal: false,
       config_target_slug: nil,
       config_preview: nil
     )}
  end

  defp list_types do
    Lotus.CMS.Ash.ContentType |> Query.new() |> Ash.read!(domain: AshDomain)
  end

  @impl true
  def handle_event("create_type", %{"slug" => slug, "name" => name}, socket) do
    case Ash.create(Lotus.CMS.Ash.ContentType, %{slug: slug, name: name}, domain: AshDomain) do
      {:ok, type} ->
        {:noreply,
         socket
         |> assign(
           types: list_types(),
           form: %{slug: "", name: ""},
           flash_msg: "Created Type",
           show_create_modal: false
         )
         |> push_navigate(to: ~p"/cms/types/#{type.id}")}

      {:error, e} ->
        {:noreply, assign(socket, flash_msg: Exception.message(e))}
    end
  end

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal: true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal: false)}
  end

  @impl true
  def handle_event("publish_all", _params, socket) do
    try do
      Lotus.CMS.Publisher.publish_all()
      {:noreply, assign(socket, flash_msg: "Published all types")}
    rescue
      e -> {:noreply, assign(socket, flash_msg: "Publish failed: #{Exception.message(e)}")}
    end
  end

  @impl true
  def handle_event("publish_type", %{"slug" => slug}, socket) do
    case load_type_with_fields(slug) do
      {:ok, type, fields} ->
        {:noreply,
         assign(socket,
           show_publish_modal: true,
           publish_target: type,
           publish_fields: fields,
           publish_tab: "summary",
           preview_code: nil,
           plan_checksum: nil,
           config_checksum: nil
         )}

      {:error, msg} ->
        {:noreply, assign(socket, flash_msg: msg)}
    end
  end

  @impl true
  def handle_event("confirm_publish", _params, socket) do
    slug = socket.assigns.publish_target && socket.assigns.publish_target.slug

    try do
      Lotus.CMS.Publisher.publish_from_database_with_migrations(slugs: [slug])

      {:noreply,
       assign(socket,
         flash_msg: "Published: #{slug}",
         show_publish_modal: false,
         publish_target: nil,
         publish_fields: [],
         publish_tab: "summary",
         preview_code: nil,
         plan_checksum: nil,
         config_checksum: nil
       )}
    rescue
      e ->
        {:noreply,
         assign(socket,
           flash_msg: "Publish failed: #{Exception.message(e)}",
           show_publish_modal: false,
           publish_target: nil,
           publish_fields: [],
           publish_tab: "summary",
           preview_code: nil,
           plan_checksum: nil,
           config_checksum: nil
         )}
    end
  end

  @impl true
  def handle_event("close_publish_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_publish_modal: false,
       publish_target: nil,
       publish_fields: [],
       publish_tab: "summary",
       preview_code: nil,
       plan_checksum: nil,
       config_checksum: nil
     )}
  end

  @impl true
  def handle_event("set_publish_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, publish_tab: tab)}
  end

  @impl true
  def handle_event("preview_plan", _params, socket) do
    slug = socket.assigns.publish_target && socket.assigns.publish_target.slug

    with {:ok, new_config} <- Lotus.CMS.Publisher.build_config_from_database(slug) do
      old_config = %{
        "meta" => %{"version" => "0.0.0", "name" => slug, "slug" => slug},
        "storage" => %{"table" => "cms_#{slug}s"},
        "fields" => [],
        "relationships" => []
      }

      result = MigrationOrchestrator.build(old_config, new_config)

      {:noreply,
       assign(socket,
         publish_tab: "preview",
         preview_code: result.migration_code,
         plan_checksum: result.plan_checksum,
         config_checksum: result.config_checksum
       )}
    else
      {:error, e} -> {:noreply, assign(socket, flash_msg: "Preview failed: #{inspect(e)}")}
    end
  end

  @impl true
  def handle_event("dry_run_write", _params, socket) do
    slug = socket.assigns.publish_target && socket.assigns.publish_target.slug

    with {:ok, new_config} <- Lotus.CMS.Publisher.build_config_from_database(slug) do
      old_config = %{
        "meta" => %{"version" => "0.0.0", "name" => slug, "slug" => slug},
        "storage" => %{"table" => "cms_#{slug}s"},
        "fields" => [],
        "relationships" => []
      }

      result = MigrationOrchestrator.build(old_config, new_config)
      tmp = Path.join(System.tmp_dir!(), "lotus_plan_" <> Ecto.UUID.generate())
      File.mkdir_p!(tmp)

      case MigrationWriter.write(tmp, slug, result) do
        {:ok, path} ->
          {:noreply, assign(socket, flash_msg: "Dry-run written: #{path}")}

        {:error, reason} ->
          {:noreply, assign(socket, flash_msg: "Write failed: #{inspect(reason)}")}
      end
    else
      {:error, e} -> {:noreply, assign(socket, flash_msg: "Dry-run failed: #{inspect(e)}")}
    end
  end

  # Add Field flow
  @impl true
  def handle_event("open_add_field", %{"slug" => slug}, socket) do
    {:noreply,
     assign(socket,
       show_add_field_modal: true,
       add_field_target: slug,
       add_field_form: %{name: "", type: "string"}
     )}
  end

  @impl true
  def handle_event("close_add_field_modal", _params, socket) do
    {:noreply, assign(socket, show_add_field_modal: false, add_field_target: nil)}
  end

  @impl true
  def handle_event("create_field", %{"name" => name, "type" => type}, socket) do
    slug = socket.assigns.add_field_target

    type_norm =
      type
      |> to_string()
      |> String.trim()
      |> String.trim_leading(":")
      |> String.downcase()

    with {:ok, type_rec} <-
           Lotus.CMS.Ash.ContentType
           |> Query.new()
           |> Query.filter(slug == ^slug)
           |> Ash.read_one(domain: AshDomain),
         {:ok, _field} <-
           Ash.create(
             Lotus.CMS.Ash.ContentField,
             %{content_type_id: type_rec.id, name: String.trim(to_string(name)), kind: type_norm},
             domain: AshDomain
           ) do
      {:noreply,
       assign(socket,
         show_add_field_modal: false,
         add_field_target: nil,
         types: list_types(),
         flash_msg: "Field added"
       )}
    else
      {:error, e} -> {:noreply, assign(socket, flash_msg: Exception.message(e))}
      _ -> {:noreply, assign(socket, flash_msg: "Type not found")}
    end
  end

  # View config
  @impl true
  def handle_event("view_config", %{"slug" => slug}, socket) do
    case Lotus.CMS.Publisher.build_config_from_database(slug) do
      {:ok, cfg} ->
        {:noreply,
         assign(socket,
           show_config_modal: true,
           config_target_slug: slug,
           config_preview: Jason.encode_to_iodata!(cfg, pretty: true)
         )}

      {:error, e} ->
        {:noreply, assign(socket, flash_msg: "Load config failed: #{inspect(e)}")}
    end
  end

  @impl true
  def handle_event("close_config_modal", _params, socket) do
    {:noreply,
     assign(socket, show_config_modal: false, config_target_slug: nil, config_preview: nil)}
  end

  defp load_type_with_fields(slug) do
    with {:ok, type} <-
           Lotus.CMS.Ash.ContentType
           |> Query.new()
           |> Query.filter(slug == ^slug)
           |> Query.load(:fields)
           |> Ash.read_one(domain: AshDomain),
         true <- not is_nil(type) do
      fields = (type.fields || []) |> Enum.sort_by(&(&1.order || 0))
      {:ok, type, fields}
    else
      {:error, e} -> {:error, Exception.message(e)}
      false -> {:error, "Type not found: #{slug}"}
    end
  end

  defp published?(slug) do
    Path.join([File.cwd!(), "lib", "lotus", "generated", "resources", slug <> ".ex"])
    |> File.exists?()
  end

  @impl true
  def handle_event("delete_type", %{"id" => id}, socket) do
    case Ash.get(Lotus.CMS.Ash.ContentType, id, domain: AshDomain) do
      {:ok, type} ->
        if published?(type.slug) do
          {:noreply, assign(socket, flash_msg: "Cannot delete published type")}
        else
          case Ash.destroy(type, domain: AshDomain) do
            :ok ->
              {:noreply, assign(socket, types: list_types(), flash_msg: "Deleted #{type.slug}")}

            {:error, e} ->
              {:noreply, assign(socket, flash_msg: Exception.message(e))}
          end
        end

      {:error, e} ->
        {:noreply, assign(socket, flash_msg: Exception.message(e))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Content-Type Builder</h1>
        <div class="flex items-center gap-2">
          <span class="badge badge-success">Schema Validation</span>
          <span class="badge badge-success">Projection Sync</span>
          <span class="badge badge-success">Diff/Plan/Codegen</span>
          <button phx-click="open_create_modal" class="btn btn-primary">Create Content Type</button>
        </div>
      </div>

      <%= if @show_publish_modal and @publish_target do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-3xl">
            <h3 class="font-bold text-lg">Publish Confirmation</h3>
            <p class="mt-2">
              You are about to publish:
              <span class="font-mono font-semibold">{@publish_target.slug}</span>
              — {@publish_target.name}
            </p>

            <div class="tabs tabs-boxed mt-4">
              <button
                class={"tab " <> if(@publish_tab == "summary", do: "tab-active", else: "")}
                phx-click="set_publish_tab"
                phx-value-tab="summary"
              >
                Summary
              </button>
              <button
                class={"tab " <> if(@publish_tab == "preview", do: "tab-active", else: "")}
                phx-click="preview_plan"
              >
                Preview
              </button>
            </div>

            <%= if @publish_tab == "summary" do %>
              <div class="mt-4 space-y-2">
                <h4 class="font-semibold">Fields ({length(@publish_fields)})</h4>
                <ul class="list-disc ml-6">
                  <%= for f <- @publish_fields do %>
                    <li><span class="font-mono">{f.name}</span> — {f.kind}</li>
                  <% end %>
                </ul>
              </div>
            <% else %>
              <div class="mt-4 space-y-3">
                <div class="text-sm opacity-70">
                  plan_checksum: <span class="font-mono">{@plan_checksum || "-"}</span>
                  <br /> config_checksum: <span class="font-mono">{@config_checksum || "-"}</span>
                </div>
                <pre class="bg-base-200 p-3 rounded text-sm overflow-x-auto"><%= @preview_code || "Click Preview to generate migration plan." %></pre>
              </div>
            <% end %>

            <div class="modal-action">
              <button type="button" phx-click="close_publish_modal" class="btn">Cancel</button>
              <%= if @publish_tab == "preview" do %>
                <button type="button" phx-click="dry_run_write" class="btn">Dry-run Write</button>
              <% end %>
              <button type="button" phx-click="confirm_publish" class="btn btn-primary">
                Publish
              </button>
            </div>
          </div>
          <div class="modal-backdrop" phx-click="close_publish_modal"></div>
        </div>
      <% end %>

      <%= if @show_add_field_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">
              Add Field to <span class="font-mono">{@add_field_target}</span>
            </h3>
            <form phx-submit="create_field">
              <div class="form-control mt-4">
                <label class="label"><span class="label-text">Name</span></label>
                <input type="text" name="name" class="input input-bordered" />
              </div>
              <div class="form-control mt-4">
                <label class="label"><span class="label-text">Type</span></label>
                <select name="type" class="select select-bordered">
                  <option value="string">string</option>
                  <option value="text">text</option>
                  <option value="integer">integer</option>
                  <option value="decimal">decimal</option>
                  <option value="boolean">boolean</option>
                  <option value="date">date</option>
                  <option value="datetime">datetime</option>
                  <option value="json">json</option>
                </select>
              </div>
              <div class="modal-action">
                <button type="button" class="btn" phx-click="close_add_field_modal">Cancel</button>
                <button type="submit" class="btn btn-primary">Add</button>
              </div>
            </form>
          </div>
          <div class="modal-backdrop" phx-click="close_add_field_modal"></div>
        </div>
      <% end %>

      <%= if @show_config_modal do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-3xl">
            <h3 class="font-bold text-lg">
              Config Preview — <span class="font-mono">{@config_target_slug}</span>
            </h3>
            <pre class="bg-base-200 p-3 rounded text-sm overflow-x-auto"><%= @config_preview %></pre>
            <div class="modal-action">
              <button class="btn" phx-click="close_config_modal">Close</button>
            </div>
          </div>
          <div class="modal-backdrop" phx-click="close_config_modal"></div>
        </div>
      <% end %>

      <%= if @show_create_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">Create Content Type</h3>
            <form phx-submit="create_type">
              <div class="form-control mt-4">
                <label class="label"><span class="label-text">Slug</span></label>
                <input type="text" name="slug" class="input input-bordered" placeholder="author" />
              </div>
              <div class="form-control mt-4">
                <label class="label"><span class="label-text">Name</span></label>
                <input type="text" name="name" class="input input-bordered" placeholder="Author" />
              </div>
              <div class="modal-action">
                <button type="button" class="btn" phx-click="close_modal">Cancel</button>
                <button type="submit" class="btn btn-primary">Create</button>
              </div>
            </form>
          </div>
          <div class="modal-backdrop" phx-click="close_modal"></div>
        </div>
      <% end %>

      <%= if @flash_msg do %>
        <div class="alert alert-info">{@flash_msg}</div>
      <% end %>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%= for t <- @types do %>
          <div class="card bg-base-100 shadow">
            <div class="card-body">
              <div class="flex items-center justify-between">
                <div>
                  <h2 class="card-title">{t.name}</h2>
                  <div class="text-xs opacity-70 font-mono">/{t.slug}</div>
                </div>
                <div class="space-x-2">
                  <button phx-click="publish_type" phx-value-slug={t.slug} class="btn btn-xs">
                    Publish
                  </button>
                  <button
                    phx-click="open_add_field"
                    phx-value-slug={t.slug}
                    class="btn btn-xs btn-outline"
                  >
                    + Field
                  </button>
                  <button
                    phx-click="view_config"
                    phx-value-slug={t.slug}
                    class="btn btn-xs btn-outline"
                  >
                    View Config
                  </button>
                  <button phx-click="delete_type" phx-value-id={t.id} class="btn btn-xs btn-outline">
                    Delete
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp example_entry_json(type, fields) do
    base = %{"_type" => type.slug}

    Enum.reduce(fields, base, fn f, acc ->
      Map.put(acc, f.name, example_value_for_kind(f.kind, f.default))
    end)
  end

  defp example_value_for_kind(kind, default) do
    cond do
      not is_nil(default) and default != "" -> default
      kind == "string" -> "text"
      kind == "text" -> "lorem ipsum"
      kind == "integer" -> 0
      kind == "decimal" -> 0.0
      kind == "boolean" -> false
      kind == "date" -> Date.utc_today() |> Date.to_iso8601()
      kind == "datetime" -> DateTime.utc_now() |> DateTime.to_iso8601()
      kind == "json" -> %{}
      true -> nil
    end
  end
end
