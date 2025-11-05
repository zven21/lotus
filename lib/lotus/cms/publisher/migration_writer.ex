defmodule Lotus.CMS.Publisher.MigrationWriter do
  @moduledoc """
  写入迁移文件到指定目录（通常为 sandbox 或 repo），包含计划与配置校验和注释，并包装为完整的 Ecto 迁移模块。
  """

  @spec write(String.t(), String.t(), %{
          migration_code: String.t(),
          plan_checksum: String.t(),
          config_checksum: String.t(),
          plan: %{table: String.t(), operations: list()}
        }) :: {:ok, String.t()} | {:error, term()}
  def write(
        dir,
        slug,
        %{migration_code: code, plan_checksum: plan_sum, config_checksum: cfg_sum} = result
      ) do
    File.mkdir_p!(dir)

    ts = timestamp()
    fname = "#{ts}_#{slug}_change.exs"
    path = Path.join(dir, fname)

    module_name = build_module_name(result, slug)

    header =
      """
      defmodule #{module_name} do
        use Ecto.Migration

        # plan_checksum: #{plan_sum}
        # config_checksum: #{cfg_sum}
      """
      |> String.trim_trailing()

    footer = "\nend\n"

    content = header <> "\n" <> code <> "\n" <> footer

    case File.write(path, content) do
      :ok -> {:ok, path}
      error -> error
    end
  end

  defp build_module_name(%{plan: %{table: table, operations: ops}}, slug) do
    # Decide prefix Create/Alter
    prefix = if Enum.any?(ops, &match?({:create_table}, &1)), do: "Create", else: "Alter"
    pascal_table = table |> to_string() |> Recase.to_pascal()
    "Lotus.Repo.Migrations.#{prefix}#{pascal_table}"
  rescue
    _ ->
      # Fallback to slug based module name
      "Lotus.Repo.Migrations.#{Recase.to_pascal(slug)}Change"
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()

    base =
      :io_lib.format("~4..0B~2..0B~2..0B~2..0B~2..0B~2..0B", [y, m, d, hh, mm, ss])
      |> IO.iodata_to_binary()

    uniq =
      System.unique_integer([:positive, :monotonic])
      |> rem(1000)
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    base <> uniq
  end
end
