defmodule LotusWeb.CMSLive.EntriesIndex do
  use LotusWeb, :live_view

  alias Ash.Query
  alias Inflex

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case ensure_generated_resource(slug) do
      {:ok, mod} ->
        sock =
          socket
          |> assign(
            slug: slug,
            module: mod,
            entries: [],
            modal: nil,
            form_data: %{},
            edit_rec: nil,
            rel_options: %{},
            link_rel: nil,
            link_targets: [],
            link_selected: []
          )
          |> load_entries()

        {:ok, sock}

      {:error, reason} ->
        {:ok,
         socket
         |> put_flash(:error, "无法加载类型 #{slug}: #{inspect(reason)}")
         |> assign(slug: slug, module: nil, entries: [], modal: nil)}
    end
  end

  defp list_entries(mod, _opts \\ %{}) do
    q = mod |> Query.new()

    entries = Ash.read!(q, domain: Lotus.CMS.Generated)

    # 预加载 belongs_to 关系，便于展示标签而非 UUID
    belongs = relation_belongs_to(mod) |> Enum.map(& &1.name)

    case belongs do
      [] ->
        entries

      rels ->
        Ash.load!(entries, rels, domain: Lotus.CMS.Generated)
    end
  end

  defp ensure_generated_resource(slug) do
    # 基于 Domain 中注册资源来匹配，避免命名/加载不确定性
    mods = Ash.Domain.Info.resources(Lotus.CMS.Generated)

    mod =
      Enum.find(mods, fn m ->
        m
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
        |> Kernel.==(slug)
      end)

    if mod do
      {:ok, mod}
    else
      {:error, :not_found}
    end
  end

  defp ash_resource?(mod) when is_atom(mod) do
    Code.ensure_loaded?(mod) and function_exported?(mod, :__ash_resource__, 0)
  end

  @impl true
  def handle_event("open_new", _params, socket) do
    case socket.assigns.module do
      nil ->
        slug = socket.assigns.slug

        case ensure_generated_resource(slug) do
          {:ok, mod} ->
            {:noreply,
             socket
             |> assign(module: mod, modal: :new, form_data: %{})
             |> load_relation_options()}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "无法创建，新类型未就绪: #{inspect(reason)}")}
        end

      _mod ->
        {:noreply, socket |> assign(modal: :new, form_data: %{}) |> load_relation_options()}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, modal: nil)}
  end

  @impl true
  def handle_event("save_new", %{"entry" => attrs}, socket) do
    IO.inspect(attrs, label: "attrs")
    IO.inspect(socket.assigns.module, label: "module")

    mod = socket.assigns.module

    case Ash.create(mod, attrs, domain: Lotus.CMS.Generated) |> IO.inspect(label: "create") do
      {:ok, _} ->
        {:noreply, socket |> assign(modal: nil) |> load_entries()}

      {:error, e} ->
        {:noreply, put_flash(socket, :error, Exception.message(e))}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    mod = socket.assigns.module

    case Ash.get(mod, id, domain: Lotus.CMS.Generated) do
      {:ok, rec} ->
        case Ash.destroy(rec, domain: Lotus.CMS.Generated) do
          :ok -> {:noreply, load_entries(socket)}
          {:error, e} -> {:noreply, put_flash(socket, :error, Exception.message(e))}
        end

      {:error, e} ->
        {:noreply, put_flash(socket, :error, Exception.message(e))}
    end
  end

  @impl true
  def handle_event("open_edit", %{"id" => id}, socket) do
    mod = socket.assigns.module

    case Ash.get(mod, id, domain: Lotus.CMS.Generated) do
      {:ok, rec} ->
        {:noreply,
         socket
         |> assign(modal: :edit, edit_rec: rec, form_data: Map.from_struct(rec))
         |> load_relation_options()}

      {:error, e} ->
        {:noreply, put_flash(socket, :error, Exception.message(e))}
    end
  end

  @impl true
  def handle_event("open_show", %{"id" => id}, socket) do
    mod = socket.assigns.module

    case Ash.get(mod, id, domain: Lotus.CMS.Generated) do
      {:ok, rec} ->
        {:noreply, socket |> assign(modal: :show, edit_rec: rec)}

      {:error, e} ->
        {:noreply, put_flash(socket, :error, Exception.message(e))}
    end
  end

  @impl true
  def handle_event("open_link", %{"id" => id, "rel" => rel}, socket) do
    mod = socket.assigns.module
    rel_atom = String.to_atom(rel)

    case Ash.get(mod, id, domain: Lotus.CMS.Generated) do
      {:ok, rec} ->
        with {:ok, selected_ids} <- fetch_related_ids(rec, rel_atom),
             {:ok, options} <- list_relation_targets(mod, rel_atom) do
          {:noreply,
           socket
           |> assign(
             modal: :link,
             edit_rec: rec,
             link_rel: rel_atom,
             link_targets: options,
             link_selected: selected_ids
           )}
        else
          {:error, e} -> {:noreply, put_flash(socket, :error, Exception.message(e))}
        end

      {:error, e} ->
        {:noreply, put_flash(socket, :error, Exception.message(e))}
    end
  end

  @impl true
  def handle_event("save_link", %{"rel" => rel, "ids" => ids_params} = _params, socket) do
    rel_atom = to_atom(rel)
    ids = normalize_ids_param(ids_params)
    rec = socket.assigns.edit_rec

    changeset =
      rec
      |> Ash.Changeset.new()
      |> Ash.Changeset.manage_relationship(rel_atom, ids, type: :append_and_remove)

    case Ash.update(changeset, domain: Lotus.CMS.Generated) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(modal: nil, link_rel: nil, link_targets: [], link_selected: [])
         |> load_entries()}

      {:error, e} ->
        {:noreply, put_flash(socket, :error, Exception.message(e))}
    end
  end

  @impl true
  def handle_event("save_edit", %{"entry" => attrs}, socket) do
    mod = socket.assigns.module
    rec = socket.assigns.edit_rec

    case Ash.update(rec, sanitize_attrs(mod, attrs), domain: Lotus.CMS.Generated) do
      {:ok, _} -> {:noreply, socket |> assign(modal: nil, edit_rec: nil) |> load_entries()}
      {:error, e} -> {:noreply, put_flash(socket, :error, Exception.message(e))}
    end
  end

  @impl true
  def handle_event("set_status", %{"id" => id, "to" => to}, socket) do
    mod = socket.assigns.module

    if attribute_exists?(mod, :status) do
      case Ash.get(mod, id, domain: Lotus.CMS.Generated) do
        {:ok, rec} ->
          case Ash.update(rec, %{status: to}, domain: Lotus.CMS.Generated) do
            {:ok, _} -> {:noreply, load_entries(socket)}
            {:error, e} -> {:noreply, put_flash(socket, :error, Exception.message(e))}
          end

        {:error, e} ->
          {:noreply, put_flash(socket, :error, Exception.message(e))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_api", params, socket) do
    id = Map.get(params || %{}, "id")
    slug = socket.assigns.slug
    mod = socket.assigns.module
    fields = mod && field_schema(mod) |> Enum.map(fn {n, _} -> n end)

    ctx = %{
      id: id,
      json: build_jsonapi_examples(slug, mod, id),
      graphql: build_graphql_examples(slug, fields, id)
    }

    {:noreply, assign(socket, modal: :api, api_context: ctx, api_tab: :json)}
  end

  @impl true
  def handle_event("switch_api_tab", %{"to" => to}, socket) do
    tab = if(to == "graphql", do: :graphql, else: :json)
    {:noreply, assign(socket, api_tab: tab)}
  end

  defp to_atom(v) when is_atom(v), do: v
  defp to_atom(v) when is_binary(v), do: String.to_atom(v)
  defp to_atom(v), do: v

  defp attribute_exists?(mod, name) do
    mod |> Ash.Resource.Info.attribute(name) |> is_map()
  end

  defp sanitize_attrs(mod, attrs) do
    fields = creatable_fields(mod)

    attrs
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      key = to_string(k)

      if key in fields do
        Map.put(acc, String.to_atom(key), normalize_value(v))
      else
        acc
      end
    end)
  end

  defp normalize_value(v) when is_binary(v) do
    trimmed = String.trim(v)

    case Jason.decode(trimmed) do
      {:ok, json} -> json
      _ -> if trimmed == "", do: nil, else: trimmed
    end
  end

  defp normalize_value(v), do: v

  defp system_fields do
    ["id", "inserted_at", "updated_at"]
  end

  defp creatable_fields(mod) do
    all = mod |> Ash.Resource.Info.attributes() |> Enum.map(&to_string(&1.name))
    Enum.reject(all, fn n -> n in system_fields() end)
  end

  defp field_schema(mod) do
    rels =
      mod
      |> Ash.Resource.Info.relationships()
      |> Enum.filter(fn r -> r.type == :belongs_to end)

    belongs_fields = Enum.map(rels, fn r -> {r.name, :belongs_to} end)

    # 隐藏 *_id 裸字段，若存在对应 belongs_to 关系
    attr_fields =
      mod
      |> Ash.Resource.Info.attributes()
      |> Enum.reject(fn a -> to_string(a.name) in system_fields() end)
      |> Enum.reject(fn a ->
        name = to_string(a.name)
        String.ends_with?(name, "_id") and Enum.any?(rels, fn r -> name == "#{r.name}_id" end)
      end)
      |> Enum.map(fn a -> {a.name, a.type} end)

    attr_fields ++ belongs_fields
  end

  defp relation_belongs_to(mod) do
    mod
    |> Ash.Resource.Info.relationships()
    |> Enum.filter(fn r -> r.type == :belongs_to end)
  end

  defp relation_many(mod) do
    mod
    |> Ash.Resource.Info.relationships()
    |> Enum.filter(fn r -> r.type in [:has_many, :many_to_many] end)
  end

  defp load_relation_options(socket) do
    mod = socket.assigns.module

    if is_nil(mod) do
      return = assign(socket, rel_options: %{})
      return
    else
      belongs = relation_belongs_to(mod)

      options =
        Enum.reduce(belongs, %{}, fn r, acc ->
          target = r.destination

          items =
            target
            |> Query.new()
            |> Query.limit(50)
            |> Ash.read!(domain: Lotus.CMS.Generated)

          Map.put(acc, r.name, Enum.map(items, &{relation_label(&1), &1.id}))
        end)

      assign(socket, rel_options: options)
    end
  end

  defp relation_label(rec) do
    m = Map.from_struct(rec)
    candidate_keys = [:name, :title, :slug, :email, :id]
    key = Enum.find(candidate_keys, fn k -> Map.get(m, k) not in [nil, ""] end) || :id
    to_string(Map.get(m, key))
  end

  defp list_relation_targets(mod, rel_name) do
    rel = mod |> Ash.Resource.Info.relationship(rel_name)

    if rel do
      target = rel.destination

      items =
        target
        |> Query.new()
        |> Query.limit(100)
        |> Ash.read!(domain: Lotus.CMS.Generated)

      {:ok, Enum.map(items, &{relation_label(&1), &1.id})}
    else
      {:error, ArgumentError.exception("Unknown relation #{rel_name}")}
    end
  end

  defp fetch_related_ids(rec, rel_name) do
    case Ash.load(rec, [rel_name], domain: Lotus.CMS.Generated) do
      {:ok, loaded} ->
        list = Map.get(loaded, rel_name) || []
        ids = Enum.map(list, & &1.id)
        {:ok, ids}

      {:error, e} ->
        {:error, e}
    end
  end

  defp detail_kv(nil), do: []

  defp detail_kv(rec) do
    mod = rec.__struct__

    fields =
      field_schema(mod)
      |> Enum.map(fn {name, type} ->
        case type do
          :belongs_to ->
            # 优先展示已预加载的关联标签，否则回退到 UUID
            assoc = Map.get(rec, name)

            value =
              case assoc do
                nil -> Map.get(rec, String.to_atom("#{name}_id"))
                _ -> relation_label(assoc)
              end

            {name, value}

          _ ->
            {name, Map.get(rec, name)}
        end
      end)

    # 追加系统字段，方便查看
    sys = [
      {:id, Map.get(rec, :id)},
      {:inserted_at, Map.get(rec, :inserted_at)},
      {:updated_at, Map.get(rec, :updated_at)}
    ]

    # 去重，系统字段放前面
    sys ++ Enum.reject(fields, fn {k, _} -> k in [:id, :inserted_at, :updated_at] end)
  end

  defp normalize_ids_param(nil), do: []
  defp normalize_ids_param(ids) when is_list(ids), do: ids
  defp normalize_ids_param(id), do: [id]

  defp load_entries(socket) do
    entries = list_entries(socket.assigns.module)
    assign(socket, entries: entries)
  end

  defp build_jsonapi_curl(slug, nil) do
    base = api_base()
    "curl -s -H 'Accept: application/vnd.api+json' \"#{base}/api/#{slug}\""
  end

  defp build_jsonapi_curl(slug, id) do
    base = api_base()
    "curl -s -H 'Accept: application/vnd.api+json' \"#{base}/api/#{slug}/#{id}\""
  end

  defp build_graphql_curl(slug, fields, nil) do
    base = api_base()
    plural = Inflex.pluralize(slug)
    sel = graphql_selection(fields)
    body = Jason.encode!(%{"query" => "query { #{plural} { results { #{sel} } } }"})
    "curl -s -H 'Content-Type: application/json' -X POST #{base}/api/graphql -d '#{body}'"
  end

  defp build_graphql_curl(slug, fields, id) do
    base = api_base()
    sel = graphql_selection(fields)

    body =
      Jason.encode!(%{
        "query" => "query($id: ID!) { #{slug}(id: $id) { #{sel} } }",
        "variables" => %{"id" => id}
      })

    "curl -s -H 'Content-Type: application/json' -X POST #{base}/api/graphql -d '#{body}'"
  end

  defp graphql_selection(fields) do
    candidates = fields || []

    names =
      candidates
      |> Enum.map(&to_string/1)
      |> Enum.reject(&(&1 in ["inserted_at", "updated_at"]))
      |> Enum.uniq()

    base = ["id" | names]
    Enum.join(base, " ")
  end

  defp api_base do
    "http://localhost:4000"
  end

  # ---------------- API snippets -----------------
  defp build_jsonapi_examples(slug, mod, id) do
    attrs_sample = jsonapi_attrs_sample(mod)
    base = api_base()

    %{
      list: "curl -s -H 'Accept: application/vnd.api+json' #{base}/api/#{slug}",
      get_one:
        "curl -s -H 'Accept: application/vnd.api+json' #{base}/api/#{slug}/#{id || "<id>"}",
      create:
        "curl -s -H 'Content-Type: application/vnd.api+json' -X POST #{base}/api/#{slug} -d '" <>
          Jason.encode!(%{
            data: %{
              type: slug,
              attributes: attrs_sample
            }
          }) <> "'",
      update:
        "curl -s -H 'Content-Type: application/vnd.api+json' -X PATCH #{base}/api/#{slug}/#{id || "<id>"} -d '" <>
          Jason.encode!(%{
            data: %{
              id: id || "<id>",
              type: slug,
              attributes: attrs_sample
            }
          }) <> "'",
      delete: "curl -s -X DELETE #{base}/api/#{slug}/#{id || "<id>"}"
    }
  end

  defp jsonapi_attrs_sample(mod) do
    ((mod && creatable_fields(mod)) || [])
    |> Enum.reduce(%{}, fn name, acc -> Map.put(acc, name, sample_value_for(name)) end)
  end

  defp sample_value_for(name) do
    cond do
      String.ends_with?(name, "_id") -> "<uuid>"
      name in ["title", "name", "slug"] -> "text"
      name in ["body", "bio"] -> "lorem"
      true -> "value"
    end
  end

  defp build_graphql_examples(slug, fields, id) do
    plural = Inflex.pluralize(slug)
    pascal = Macro.camelize(slug)
    sel = graphql_selection(fields)

    %{
      list:
        """
        query {
          #{plural} { results { #{sel} } }
        }
        """
        |> String.trim(),
      get_one:
        """
        query($id: ID!) {
          #{slug}(id: $id) { #{sel} }
        }
        """
        |> String.trim(),
      create:
        """
        mutation($input: Create#{pascal}Input!) {
          create#{pascal}(input: $input) { result { #{sel} } errors { message } }
        }
        """
        |> String.trim(),
      update:
        """
        mutation($id: ID!, $input: Update#{pascal}Input!) {
          update#{pascal}(id: $id, input: $input) { result { #{sel} } errors { message } }
        }
        """
        |> String.trim(),
      delete:
        """
        mutation($id: ID!) {
          delete#{pascal}(id: $id) { result { id } errors { message } }
        }
        """
        |> String.trim()
    }
  end

  defp value_for_field(rec, {name, type}) do
    case type do
      :belongs_to ->
        # 优先展示已预加载的关联记录的可读标签，否则回退到 UUID
        assoc = Map.get(rec, name)

        case assoc do
          nil -> Map.get(rec, String.to_atom("#{name}_id"))
          _ -> relation_label(assoc)
        end

      :map ->
        case Map.get(rec, name) do
          nil -> nil
          v when is_map(v) or is_list(v) -> Jason.encode!(v)
          v -> to_string(v)
        end

      _ ->
        Map.get(rec, name)
    end
  end

  # to_int 不再需要（分页已移除）

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 space-y-6">
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold">Manage Entries</h1>
        <div class="flex items-center gap-2">
          <button class="btn btn-primary" phx-click="open_new">New {@slug}</button>
          <button class="btn" phx-click="open_api">API</button>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>ID</th>
              <%= for {name, _type} <- field_schema(@module) do %>
                <th>{name}</th>
              <% end %>
              <th>Inserted</th>
              <th class="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for e <- @entries do %>
              <tr>
                <td class="font-mono">
                  <button class="link link-primary" phx-click="open_show" phx-value-id={e.id}>
                    {e.id}
                  </button>
                </td>
                <%= for field <- field_schema(@module) do %>
                  <td>{value_for_field(e, field)}</td>
                <% end %>
                <td>{Map.get(e, :inserted_at)}</td>
                <td class="text-right">
                  <%= if @module |> Ash.Resource.Info.attribute(:status) do %>
                    <%= if Map.get(e, :status) == "published" do %>
                      <button
                        class="btn btn-xs"
                        phx-click="set_status"
                        phx-value-id={e.id}
                        phx-value-to="draft"
                      >
                        Mark Draft
                      </button>
                    <% else %>
                      <button
                        class="btn btn-xs"
                        phx-click="set_status"
                        phx-value-id={e.id}
                        phx-value-to="published"
                      >
                        Publish
                      </button>
                    <% end %>
                  <% end %>
                  <button class="btn btn-xs" phx-click="open_edit" phx-value-id={e.id}>Edit</button>
                  <button class="btn btn-xs btn-error" phx-click="delete" phx-value-id={e.id}>
                    Delete
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @modal == :new do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-3xl">
            <h3 class="font-bold text-lg">Create Entry</h3>
            <form phx-submit="save_new" class="mt-4 space-y-3">
              <%= for {name, type} <- field_schema(@module) do %>
                <div class="form-control">
                  <label class="label"><span class="label-text">{name} ({type})</span></label>
                  <%= if type == :belongs_to do %>
                    <select name={"entry[#{name}_id]"} class="select select-bordered">
                      <option value="">--</option>
                      <%= for {label, id} <- @rel_options[name] do %>
                        <option value={id}>{label}</option>
                      <% end %>
                    </select>
                  <% else %>
                    <%= case to_string(type) do %>
                      <% "boolean" -> %>
                        <input type="checkbox" name={"entry[#{name}]"} class="toggle" />
                      <% "integer" -> %>
                        <input type="number" name={"entry[#{name}]"} class="input input-bordered" />
                      <% "map" -> %>
                        <textarea
                          name={"entry[#{name}]"}
                          class="textarea textarea-bordered"
                          placeholder="JSON"
                        ></textarea>
                      <% _ -> %>
                        <input type="text" name={"entry[#{name}]"} class="input input-bordered" />
                    <% end %>
                  <% end %>
                </div>
              <% end %>
              <div class="flex justify-end gap-2">
                <button type="button" class="btn" phx-click="close_modal">Cancel</button>
                <button class="btn btn-primary" type="submit">Create</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%= if @modal == :edit do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-3xl">
            <h3 class="font-bold text-lg">Edit Entry</h3>
            <form phx-submit="save_edit" class="mt-4 space-y-3">
              <%= for {name, type} <- field_schema(@module) do %>
                <div class="form-control">
                  <label class="label"><span class="label-text">{name} ({type})</span></label>
                  <%= if type == :belongs_to do %>
                    <select
                      name={"entry[#{name}_id]"}
                      class="select select-bordered"
                      value={Map.get(@edit_rec, String.to_atom("#{name}_id"))}
                    >
                      <option value="">--</option>
                      <%= for {label, id} <- @rel_options[name] do %>
                        <option
                          value={id}
                          selected={Map.get(@edit_rec, String.to_atom("#{name}_id")) == id}
                        >
                          {label}
                        </option>
                      <% end %>
                    </select>
                  <% else %>
                    <%= case to_string(type) do %>
                      <% "boolean" -> %>
                        <input
                          type="checkbox"
                          name={"entry[#{name}]"}
                          class="toggle"
                          checked={Map.get(@edit_rec, name)}
                        />
                      <% "integer" -> %>
                        <input
                          type="number"
                          name={"entry[#{name}]"}
                          class="input input-bordered"
                          value={Map.get(@edit_rec, name)}
                        />
                      <% "map" -> %>
                        <textarea
                          name={"entry[#{name}]"}
                          class="textarea textarea-bordered"
                          placeholder="JSON"
                        ><%= Jason.encode!(Map.get(@edit_rec, name) || %{}) %></textarea>
                      <% _ -> %>
                        <input
                          type="text"
                          name={"entry[#{name}]"}
                          class="input input-bordered"
                          value={Map.get(@edit_rec, name)}
                        />
                    <% end %>
                  <% end %>
                </div>
              <% end %>
              <div class="flex justify-end gap-2">
                <button type="button" class="btn" phx-click="close_modal">Cancel</button>
                <button class="btn btn-primary" type="submit">Save</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%= if @modal == :link do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-3xl">
            <h3 class="font-bold text-lg">Link {@link_rel}</h3>
            <form phx-submit="save_link" class="mt-4 space-y-2">
              <div class="max-h-80 overflow-auto border rounded">
                <table class="table table-zebra w-full">
                  <thead>
                    <tr>
                      <th></th>
                      <th>ID</th>
                      <th>Label</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for {label, id} <- @link_targets do %>
                      <tr>
                        <td>
                          <input
                            type="checkbox"
                            name="ids[]"
                            value={id}
                            checked={id in @link_selected}
                          />
                        </td>
                        <td class="font-mono">{id}</td>
                        <td>{label}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
              <div class="flex justify-end gap-2">
                <button type="button" class="btn" phx-click="close_modal">Cancel</button>
                <input type="hidden" name="rel" value={@link_rel} />
                <button class="btn btn-primary" type="submit">Save Links</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%= if @modal == :show do %>
        <div class="modal modal-open">
          <div class="modal-box max-w-3xl">
            <h3 class="font-bold text-lg">Entry Detail</h3>
            <div class="mt-4 max-h-96 overflow-auto">
              <table class="table w-full">
                <thead>
                  <tr>
                    <th>Field</th>
                    <th>Value</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for {k, v} <- detail_kv(@edit_rec) do %>
                    <tr>
                      <td class="font-mono">{k}</td>
                      <td>
                        <%= if is_map(v) or is_list(v) do %>
                          <pre class="whitespace-pre-wrap text-sm">{Jason.encode!(v)}</pre>
                        <% else %>
                          {to_string(v)}
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
            <div class="flex justify-end gap-2 mt-4">
              <button
                type="button"
                class="btn"
                phx-click="open_api"
                phx-value-id={@edit_rec && @edit_rec.id}
              >
                API
              </button>
              <button type="button" class="btn" phx-click="close_modal">Close</button>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @modal == :api do %>
        <div class="drawer drawer-end open">
          <input id="api-drawer" type="checkbox" class="drawer-toggle" checked />
          <div class="drawer-content"></div>
          <div class="drawer-side z-50">
            <label for="api-drawer" class="drawer-overlay" phx-click="close_modal"></label>
            <div class="min-h-full w-[42rem] bg-base-100 p-6 space-y-4 shadow-2xl">
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-bold">
                  API Examples ({@slug}{@api_context && @api_context.id && ":" <> @api_context.id})
                </h3>
                <button class="btn btn-sm" phx-click="close_modal">Close</button>
              </div>
              <div class="tabs tabs-boxed w-fit">
                <a
                  class={"tab #{if @api_tab == :json, do: "tab-active"}"}
                  phx-click="switch_api_tab"
                  phx-value-to="json"
                >
                  JSON:API
                </a>
                <a
                  class={"tab #{if @api_tab == :graphql, do: "tab-active"}"}
                  phx-click="switch_api_tab"
                  phx-value-to="graphql"
                >
                  GraphQL
                </a>
              </div>

              <%= if @api_tab == :json do %>
                <div class="space-y-3">
                  <h4 class="font-semibold">List</h4>
                  <pre class="bg-base-200 p-3 rounded text-xs overflow-x-auto"><%= @api_context.json.list %></pre>
                  <h4 class="font-semibold">Get One</h4>
                  <pre class="bg-base-200 p-3 rounded text-xs overflow-x-auto"><%= @api_context.json.get_one %></pre>
                  <h4 class="font-semibold">Create</h4>
                  <pre class="bg-base-200 p-3 rounded text-xs overflow-x-auto"><%= @api_context.json.create %></pre>
                  <h4 class="font-semibold">Update</h4>
                  <pre class="bg-base-200 p-3 rounded text-xs overflow-x-auto"><%= @api_context.json.update %></pre>
                  <h4 class="font-semibold">Delete</h4>
                  <pre class="bg-base-200 p-3 rounded text-xs overflow-x-auto"><%= @api_context.json.delete %></pre>
                </div>
              <% else %>
                <div class="space-y-3">
                  <h4 class="font-semibold">List (query)</h4>
                  <pre class="bg-base-200 p-3 rounded text-xs overflow-x-auto"><%= @api_context.graphql.list %></pre>
                  <h4 class="font-semibold">Get One (query)</h4>
                  <pre class="bg-base-200 p-3 rounded text-xs overflow-x-auto"><%= @api_context.graphql.get_one %></pre>
                  <h4 class="font-semibold">Create (mutation)</h4>
                  <pre class="bg-base-200 p-3 rounded text-xs overflow-x-auto"><%= @api_context.graphql.create %></pre>
                  <h4 class="font-semibold">Update (mutation)</h4>
                  <pre class="bg-base-200 p-3 rounded text-xs overflow-x-auto"><%= @api_context.graphql.update %></pre>
                  <h4 class="font-semibold">Delete (mutation)</h4>
                  <pre class="bg-base-200 p-3 rounded text-xs overflow-x-auto"><%= @api_context.graphql.delete %></pre>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
