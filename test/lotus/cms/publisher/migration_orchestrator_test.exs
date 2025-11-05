defmodule Lotus.CMS.Publisher.MigrationOrchestratorTest do
  use ExUnit.Case, async: true

  alias Lotus.CMS.Publisher.MigrationOrchestrator

  test "orchestrates diff→plan→codegen and returns checksums" do
    old = %{
      "meta" => %{"version" => "1.0.0", "name" => "Author", "slug" => "author"},
      "storage" => %{"table" => "cms_authors"},
      "fields" => [%{"name" => "name", "type" => "string"}],
      "relationships" => []
    }

    new = %{
      "meta" => %{"version" => "1.1.0", "name" => "Author", "slug" => "author"},
      "storage" => %{"table" => "cms_authors"},
      "fields" => [
        %{"name" => "name", "type" => "text"},
        %{"name" => "email", "type" => "string"}
      ],
      "relationships" => []
    }

    result = MigrationOrchestrator.build(old, new)

    assert %{plan: plan, migration_code: code, plan_checksum: plan_sum, config_checksum: cfg_sum} =
             result

    assert is_binary(code) and code =~ "alter table(:cms_authors)"
    assert is_binary(plan_sum) and byte_size(plan_sum) == 64
    assert is_binary(cfg_sum) and byte_size(cfg_sum) == 64

    # Idempotent for same inputs
    result2 = MigrationOrchestrator.build(old, new)
    assert result.plan_checksum == result2.plan_checksum
    assert result.config_checksum == result2.config_checksum
  end
end
