defmodule Lotus.CMS.Publisher.Generators.Audit do
  @moduledoc """
  审计日志生成器

  职责：
  - 生成审计日志记录逻辑
  - 支持变更追踪
  - 支持元数据记录
  """

  @doc """
  生成审计变更列表
  """
  def generate_audit_changes(config, action) do
    audit_config = Map.get(config, "audit", %{})

    if Map.get(audit_config, "enabled", false) do
      [
        generate_audit_change(audit_config, action)
      ]
    else
      []
    end
  end

  defp generate_audit_change(audit_config, action) do
    _track_changes = Map.get(audit_config, "track_changes", true)
    events = Map.get(audit_config, "events", [])
    _metadata_config = Map.get(audit_config, "metadata", %{})

    if action in events do
      quote do
        # TODO: 实现审计日志记录
        # after_action(fn changeset, record ->
        #   Lotus.CMS.Audit.record(
        #     resource_type: unquote(action),
        #     resource_id: record.id,
        #     action: unquote(action),
        #     changes: if(unquote(_track_changes), do: changeset.params, else: nil),
        #     before_state: if(unquote(_metadata_config["include_before_state"]), do: changeset.data, else: nil),
        #     after_state: if(unquote(_metadata_config["include_after_state"]), do: record, else: nil),
        #     actor_id: changeset.context[:actor][:id],
        #     ip_address: if(unquote(_metadata_config["include_ip"]), do: changeset.context[:ip], else: nil),
        #     request_id: if(unquote(_metadata_config["include_request_id"]), do: changeset.context[:request_id], else: nil)
        #   )
        # end)
      end
    else
      quote do
        # 此动作不记录审计日志
      end
    end
  end
end
