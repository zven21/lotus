defmodule Lotus.CMS.Publisher.MigrationOrchestrator do
  @moduledoc """
  高层编排：输入 old/new 配置，产出 diff、plan、迁移代码与校验和。
  """

  alias Lotus.CMS.Publisher.{DiffEngine, MigrationPlan, MigrationCodegen}

  @spec build(map(), map()) :: %{
          plan: map(),
          migration_code: String.t(),
          plan_checksum: String.t(),
          config_checksum: String.t()
        }
  def build(old_config, new_config) do
    diff = DiffEngine.diff(old_config, new_config)
    plan = MigrationPlan.generate(old_config, new_config, diff)
    code = MigrationCodegen.to_ecto_change(plan)

    %{
      plan: plan,
      migration_code: code,
      plan_checksum: MigrationCodegen.checksum(plan),
      config_checksum: checksum_config(new_config)
    }
  end

  defp checksum_config(cfg) do
    cfg
    |> :erlang.term_to_binary()
    |> (&:crypto.hash(:sha256, &1)).()
    |> Base.encode16(case: :lower)
  end
end
