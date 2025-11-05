defmodule LotusWeb.CMSLive.TypeShow do
  use LotusWeb, :live_view
  alias Lotus.CMS.AshDomain
  alias Ash.Query
  require Ash.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     load(
       assign(socket,
         id: id,
         form: %{name: "", kind: "string", rel_target: "", rel_backref: ""},
         rel_form: %{name: "", type: "manyToOne", target: "", foreign_key: "", target_field: ""},
         modal: nil,
         bulk_text: "name:string\nemail:string\nbio:text"
       )
     )}
  end

  defp load(socket) do
    type = Ash.get!(Lotus.CMS.Ash.ContentType, socket.assigns.id, domain: AshDomain)

    fields =
      Lotus.CMS.Ash.ContentField
      |> Query.filter(content_type_id: type.id)
      |> Query.sort(order: :asc)
      |> Ash.read!(domain: AshDomain)

    relations =
      Lotus.CMS.Ash.ContentRelation
      |> Query.filter(content_type_id: type.id)
      |> Query.sort(inserted_at: :desc)
      |> Ash.read!(domain: AshDomain)

    all_types =
      Lotus.CMS.Ash.ContentType
      |> Query.sort(inserted_at: :desc)
      |> Ash.read!(domain: AshDomain)

    assign(socket, type: type, fields: fields, relations: relations, all_types: all_types)
  end

  # 将所有 handle_event/3 定义放在一起，避免编译告警

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 space-y-6">
      <div class="breadcrumbs text-sm">
        <ul>
          <li><.link navigate={~p"/cms"}>CMS</.link></li>
          <li>Fields of <span class="font-mono">/{@type.slug}</span></li>
        </ul>
      </div>

      <div class="space-y-6">
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">Create Field</h2>
              <span class="text-xs opacity-70">
                Type: <span class="font-mono">/{@type.slug}</span>
              </span>
            </div>
            <form
              phx-submit="create_field"
              phx-change="field_form_change"
              class="grid grid-cols-1 md:grid-cols-6 gap-4"
            >
              <input
                name="name"
                placeholder="name"
                class="input input-bordered md:col-span-2"
                value={@form.name}
              />
              <select name="kind" class="select select-bordered" value={@form.kind}>
                <option>string</option>
                <option>text</option>
                <option>integer</option>
                <option>boolean</option>
                <option>json</option>
                <option>relation</option>
              </select>
              <%= if @form.kind == "relation" do %>
                <select name="rel_target" class="select select-bordered md:col-span-2">
                  <option value="">-- select target type --</option>
                  <%= for t <- @all_types do %>
                    <option value={t.slug} selected={@form.rel_target == t.slug}>
                      {t.name} ({t.slug})
                    </option>
                  <% end %>
                </select>
                <input
                  name="rel_backref"
                  placeholder="backref name (optional)"
                  class="input input-bordered"
                  value={@form.rel_backref}
                />
              <% else %>
                <div class="hidden md:col-span-3"></div>
              <% end %>
              <div class="md:col-span-1 flex justify-end">
                <button class="btn btn-primary" type="submit">Add</button>
              </div>
            </form>
            <div class="mt-3">
              <button class="btn btn-sm btn-primary" phx-click="open_bulk_add">
                Quick Add (Batch)
              </button>
            </div>
          </div>
        </div>

        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">Create Relation</h2>
              <span class="text-xs opacity-70">Backref/外键将自动建议</span>
            </div>
            <form phx-submit="create_relation" class="grid grid-cols-1 md:grid-cols-6 gap-3">
              <input name="name" placeholder="name (alias)" class="input input-bordered" />
              <select name="type" class="select select-bordered">
                <option value="manyToOne">manyToOne</option>
                <option value="oneToMany">oneToMany</option>
                <option value="oneToOne">oneToOne</option>
                <option value="manyToMany">manyToMany</option>
              </select>
              <select name="target" class="select select-bordered">
                <option value="">-- select target type --</option>
                <%= for t <- @all_types do %>
                  <option value={t.slug}>{t.name} ({t.slug})</option>
                <% end %>
              </select>
              <input
                name="foreign_key"
                placeholder="foreign_key (default: name_id)"
                class="input input-bordered"
              />
              <input
                name="target_field"
                placeholder="target_field (for oneToMany backref)"
                class="input input-bordered"
              />
              <label class="label cursor-pointer md:col-span-2">
                <span class="label-text">Auto create reverse relation</span>
                <input type="checkbox" name="create_backref" checked class="toggle" />
              </label>
              <div class="md:col-span-6 flex justify-end">
                <button class="btn btn-primary" type="submit">Add Relation</button>
              </div>
            </form>
          </div>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Kind</th>
              <th>Required</th>
              <th>Unique</th>
              <th>Order</th>
              <th class="text-right"></th>
            </tr>
          </thead>
          <tbody>
            <%= for f <- @fields do %>
              <tr>
                <td class="font-mono">{f.name}</td>
                <td>
                  <span class="badge badge-outline">{f.kind}</span>
                </td>
                <td>
                  <%= if f.required do %>
                    <span class="badge badge-primary">Yes</span>
                  <% else %>
                    <span class="badge">No</span>
                  <% end %>
                </td>
                <td>
                  <%= if f.unique do %>
                    <span class="badge badge-primary">Yes</span>
                  <% else %>
                    <span class="badge">No</span>
                  <% end %>
                </td>
                <td class="font-mono">{f.order}</td>
                <td class="text-right">
                  <button phx-click="delete_field" phx-value-id={f.id} class="btn btn-xs btn-error">
                    Delete
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Target</th>
              <th>Foreign Key</th>
              <th>Target Field</th>
            </tr>
          </thead>
          <tbody>
            <%= for r <- @relations do %>
              <tr>
                <td class="font-mono">{r.name}</td>
                <td><span class="badge badge-outline">{r.type}</span></td>
                <td class="font-mono">{r.target}</td>
                <td class="font-mono">{r.foreign_key}</td>
                <td class="font-mono">{r.target_field}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @modal == :bulk_fields do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-3xl">
            <h3 class="font-bold text-lg">Batch Add Fields</h3>
            <p class="text-sm opacity-70 mt-1">支持两种格式：每行 <code>name:kind</code> 或粘贴 JSON 数组。</p>
            <form phx-submit="bulk_add_fields" class="mt-3 space-y-3">
              <textarea
                name="bulk"
                class="textarea textarea-bordered w-full h-56"
                placeholder="title:string\nbody:text"
              ><%= @bulk_text %></textarea>
              <div class="flex gap-2 justify-end">
                <button type="button" class="btn" phx-click="close_modal">Cancel</button>
                <button class="btn btn-primary" type="submit">Add Fields</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Preview</h2>
            <span class="text-xs opacity-70">Type: <span class="font-mono">/{@type.slug}</span></span>
          </div>
          <pre class="bg-base-200 p-3 rounded text-sm overflow-x-auto"><%= Jason.encode_to_iodata!(example_entry_json(@type, @fields), pretty: true) %></pre>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "create_relation",
        %{"name" => name, "type" => type, "target" => target} = params,
        socket
      ) do
    # 默认外键：name_id
    fk =
      case Map.get(params, "foreign_key") |> blank_to_nil() do
        nil -> name <> "_id"
        v -> v
      end

    # 可选自动创建反向关系（根据 seeds 的语义）
    create_backref? = Map.has_key?(params, "create_backref")

    if create_backref? and type in ["manyToOne", "oneToMany"] do
      with {:ok, target_type} <- fetch_type_by_slug(target),
           {:ok, _} <-
             create_relation_pair(
               socket.assigns.id,
               target_type.id,
               name,
               target,
               Map.get(params, "target_field")
             ) do
        {:noreply, load(socket)}
      else
        {:error, e} -> {:noreply, assign(socket, error: Exception.message(e))}
      end
    else
      attrs = %{
        content_type_id: socket.assigns.id,
        name: name,
        type: type,
        target: target,
        foreign_key: fk,
        target_field: Map.get(params, "target_field") |> blank_to_nil()
      }

      case Ash.create(Lotus.CMS.Ash.ContentRelation, attrs, domain: AshDomain) do
        {:ok, _} -> {:noreply, load(socket)}
        {:error, e} -> {:noreply, assign(socket, error: Exception.message(e))}
      end
    end
  end

  @impl true
  def handle_event("create_field", %{"name" => name, "kind" => kind} = params, socket) do
    if kind == "relation" do
      case Map.get(params, "rel_target") do
        nil ->
          {:noreply, assign(socket, error: "请选择关系目标类型")}

        "" ->
          {:noreply, assign(socket, error: "请选择关系目标类型")}

        target_slug ->
          with {:ok, target_type} <- fetch_type_by_slug(target_slug),
               {:ok, _} <-
                 create_relation_pair(
                   socket.assigns.id,
                   target_type.id,
                   name,
                   target_slug,
                   Map.get(params, "rel_backref")
                 ) do
            {:noreply,
             load(
               assign(socket,
                 form: %{name: "", kind: kind, rel_target: "", rel_backref: ""}
               )
             )}
          else
            {:error, e} -> {:noreply, assign(socket, error: Exception.message(e))}
          end
      end
    else
      case Ash.create(
             Lotus.CMS.Ash.ContentField,
             %{content_type_id: socket.assigns.id, name: name, kind: kind},
             domain: AshDomain
           ) do
        {:ok, _} -> {:noreply, load(assign(socket, form: %{name: "", kind: kind}))}
        {:error, e} -> {:noreply, assign(socket, error: Exception.message(e))}
      end
    end
  end

  @impl true
  def handle_event("field_form_change", params, socket) do
    form = %{
      name: Map.get(params, "name", socket.assigns.form.name),
      kind: Map.get(params, "kind", socket.assigns.form.kind),
      rel_target: Map.get(params, "rel_target", socket.assigns.form.rel_target),
      rel_backref: Map.get(params, "rel_backref", socket.assigns.form.rel_backref)
    }

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("delete_field", %{"id" => id}, socket) do
    case Ash.get(Lotus.CMS.Ash.ContentField, id, domain: AshDomain) do
      {:ok, field} ->
        case Ash.destroy(field, domain: AshDomain) do
          :ok -> {:noreply, load(socket)}
          {:error, e} -> {:noreply, assign(socket, error: Exception.message(e))}
        end

      {:error, e} ->
        {:noreply, assign(socket, error: Exception.message(e))}
    end
  end

  @impl true
  def handle_event("open_bulk_add", _params, socket) do
    {:noreply, assign(socket, modal: :bulk_fields)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil)}
  end

  @impl true
  def handle_event("bulk_add_fields", %{"bulk" => bulk}, socket) do
    entries = parse_bulk_text(bulk)

    results =
      Enum.map(entries, fn %{name: name, kind: kind} ->
        Ash.create(
          Lotus.CMS.Ash.ContentField,
          %{content_type_id: socket.assigns.id, name: name, kind: kind},
          domain: AshDomain
        )
      end)

    case Enum.find(results, fn
           {:error, _} -> true
           _ -> false
         end) do
      nil -> {:noreply, load(assign(socket, modal: nil))}
      {:error, e} -> {:noreply, assign(socket, error: Exception.message(e))}
    end
  end

  defp parse_bulk_text(text) do
    trimmed = String.trim(to_string(text))

    case Jason.decode(trimmed) do
      {:ok, list} when is_list(list) ->
        list
        |> Enum.map(fn item ->
          %{
            name: to_string(item["name"] || item[:name] || ""),
            kind: to_string(item["kind"] || item[:kind] || "string")
          }
        end)

      _ ->
        trimmed
        |> String.split(["\n", "\r"], trim: true)
        |> Enum.map(fn line ->
          case String.split(line, ":", parts: 2) do
            [name, kind] -> %{name: String.trim(name), kind: String.trim(kind)}
            [name] -> %{name: String.trim(name), kind: "string"}
            _ -> %{name: "", kind: "string"}
          end
        end)
    end
    |> Enum.filter(fn %{name: n} -> n != "" end)
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(v), do: v

  defp fetch_type_by_slug(slug) do
    case Lotus.CMS.Ash.ContentType |> Query.filter(slug: slug) |> Ash.read(domain: AshDomain) do
      {:ok, [type | _]} -> {:ok, type}
      {:ok, []} -> {:error, ArgumentError.exception("Unknown target type: #{slug}")}
      {:error, e} -> {:error, e}
    end
  end

  defp create_relation_pair(current_type_id, target_type_id, name, target_slug, backref_name) do
    with {:ok, current_type} <-
           Ash.get(Lotus.CMS.Ash.ContentType, current_type_id, domain: AshDomain),
         fk <- "#{name}_id",
         rev_name <-
           if(to_string(backref_name || "") == "",
             do: "#{current_type.slug}_#{name}",
             else: backref_name
           ),
         {:ok, _r1} <-
           Ash.create(
             Lotus.CMS.Ash.ContentRelation,
             %{
               content_type_id: current_type_id,
               name: name,
               type: "manyToOne",
               target: target_slug,
               foreign_key: fk
             },
             domain: AshDomain
           ),
         {:ok, _r2} <-
           Ash.create(
             Lotus.CMS.Ash.ContentRelation,
             %{
               content_type_id: target_type_id,
               name: rev_name,
               type: "oneToMany",
               target: current_type.slug,
               target_field: name
             },
             domain: AshDomain
           ) do
      {:ok, :created}
    else
      {:error, e} -> {:error, e}
    end
  end

  defp example_entry_json(type, fields) do
    base = %{"_type" => type.slug}

    Enum.reduce(fields, base, fn f, acc ->
      Map.put(acc, f.name, example_value_for_kind(f.kind))
    end)
  end

  defp example_value_for_kind(kind) do
    case kind do
      "string" -> "text"
      "text" -> "lorem ipsum"
      "integer" -> 0
      "decimal" -> 0.0
      "boolean" -> false
      "date" -> Date.utc_today() |> Date.to_iso8601()
      "datetime" -> DateTime.utc_now() |> DateTime.to_iso8601()
      "json" -> %{}
      _ -> nil
    end
  end
end
