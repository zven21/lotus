defmodule Lotus.CMS.Publisher.MigrationWriterTest do
  use ExUnit.Case, async: false

  alias Lotus.CMS.Publisher.{MigrationOrchestrator, MigrationWriter}

  test "writes migration file to sandbox with checksums in header" do
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

    tmp = Path.join(System.tmp_dir!(), "lotus_mg_" <> Ecto.UUID.generate())
    File.mkdir_p!(tmp)

    result = MigrationOrchestrator.build(old, new)

    {:ok, path} = MigrationWriter.write(tmp, "author", result)

    assert File.exists?(path)
    content = File.read!(path)

    assert content =~ "# plan_checksum: #{result.plan_checksum}"
    assert content =~ "# config_checksum: #{result.config_checksum}"
    assert content =~ "def change do"

    # filename format: TIMESTAMP_author_change.exs
    fname = Path.basename(path)
    assert String.ends_with?(fname, "_author_change.exs")

    # cleanup
    File.rm_rf!(tmp)
  end
end
