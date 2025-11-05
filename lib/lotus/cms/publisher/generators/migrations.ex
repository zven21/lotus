defmodule Lotus.CMS.Publisher.Generators.Migrations do
  @moduledoc """
  数据库迁移生成器

  职责：
  - 生成每个内容类型的建表迁移（cms_{slug_plural}）
  - 生成字段对应的强类型列
  - 生成外键约束和索引
  - 生成多对多关系的联结表
  """

  alias Inflex

  @doc """
  生成建表迁移文件的源代码字符串

  返回迁移文件的完整内容（字符串）
  """
  def generate_create_table_migration(slug, config) do
    # 使用 Inflex 将 slug 转换为复数形式
    pluralized_slug = Inflex.pluralize(slug)
    table_name = "cms_#{pluralized_slug}"
    # 保留 cms_ 前缀
    table_atom = table_name
    module_name = create_module_name(slug)

    fields = Map.get(config, "fields", [])
    relations = Map.get(config, "relationships", [])
    indexes = Map.get(config, "indexes", [])
    options = Map.get(config, "options", %{})

    columns = generate_columns(fields, relations)
    table_indexes = generate_table_indexes(fields, relations, indexes, table_name)
    unique_constraints = generate_unique_constraints(fields, table_name)

    """
    defmodule Lotus.Repo.Migrations.#{module_name} do
      use Ecto.Migration

      def change do
        create table(:#{table_atom}, primary_key: false) do
          add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
    #{columns}
          # 通用列
          #{if Map.get(options, "i18n", false), do: "add :locale, :string, size: 10, default: \"en\", null: false", else: "# add :locale, :string, size: 10, default: \"en\", null: false  # i18n disabled"}
          timestamps(type: :utc_datetime_usec)
        end
    #{table_indexes}
    #{unique_constraints}
      end
    end
    """
  end

  @doc """
  生成多对多关系的联结表迁移
  """
  def generate_join_table_migration(source_slug, relation, target_slug) do
    pluralized_source = Inflex.pluralize(source_slug)
    pluralized_target = Inflex.pluralize(target_slug)
    # 保留 cms_ 前缀
    source_table = "cms_#{pluralized_source}"
    # 保留 cms_ 前缀
    target_table = "cms_#{pluralized_target}"
    # 保留 cms_ 前缀
    join_table_name = "cms_#{pluralized_source}_#{relation["name"]}"
    source_id_col = "#{source_slug}_id"
    target_id_col = "#{target_slug}_id"
    module_name = create_join_table_module_name(source_slug, relation["name"])

    """
    defmodule Lotus.Repo.Migrations.#{module_name} do
      use Ecto.Migration

      def change do
        create table(:#{join_table_name}, primary_key: false) do
          add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
          add :#{source_id_col}, references(:#{source_table}, type: :uuid, on_delete: :delete_all), null: false
          add :#{target_id_col}, references(:#{target_table}, type: :uuid, on_delete: :delete_all), null: false
          timestamps(type: :utc_datetime_usec)
        end

        create index(:#{join_table_name}, [:#{source_id_col}])
        create index(:#{join_table_name}, [:#{target_id_col}])
        create unique_index(:#{join_table_name}, [:#{source_id_col}, :#{target_id_col}])
      end
    end
    """
  end

  @doc """
  写入迁移文件到 priv/repo/migrations 目录

  返回: {:ok, filepath} 或 {:error, reason}
  """
  def write_migration_file(slug, config) do
    migrations_dir = Path.join([File.cwd!(), "priv", "repo", "migrations"])
    File.mkdir_p!(migrations_dir)

    pluralized_slug = Inflex.pluralize(slug)
    table_name = "cms_#{pluralized_slug}"
    # 先检查是否已有任意针对该表的创建迁移，存在则跳过
    existing? =
      migrations_dir
      |> File.ls!()
      |> Enum.any?(fn fname -> String.ends_with?(fname, "_create_#{table_name}.exs") end)

    if existing? do
      {:error, :file_exists}
    else
      timestamp = generate_timestamp()
      filename = "#{timestamp}_create_#{table_name}.exs"
      filepath = Path.join(migrations_dir, filename)

      migration_content = generate_create_table_migration(slug, config)

      case File.write(filepath, migration_content) do
        :ok -> {:ok, filepath}
        error -> error
      end
    end
  end

  # 生成字段列定义（包括外键列）
  defp generate_columns(fields, relations) do
    # 生成普通字段列
    field_columns =
      Enum.map(fields, fn field ->
        field_name = Map.get(field, "name")
        field_kind = Map.get(field, "kind")
        field_required = Map.get(field, "required", false)
        field_options = Map.get(field, "options", %{})

        column_def = map_field_kind_to_column(field_kind, field_options)
        null_option = if field_required, do: "null: false", else: "null: true"

        default_value = get_default_value(field, field_kind)
        default_option = if default_value, do: "default: #{default_value}", else: ""

        options_text =
          [null_option, default_option] |> Enum.filter(&(&1 != "")) |> Enum.join(", ")

        if options_text != "",
          do: "          add :#{field_name}, #{column_def}, #{options_text}",
          else: "          add :#{field_name}, #{column_def}"
      end)

    # 生成外键列（manyToOne 关系）
    foreign_key_columns =
      relations
      |> Enum.filter(fn rel -> Map.get(rel, "type") == "manyToOne" end)
      |> Enum.map(fn rel ->
        rel_name = Map.get(rel, "name")
        target = Map.get(rel, "target")
        pluralized_target = Inflex.pluralize(target)
        # 保留 cms_ 前缀
        target_table = "cms_#{pluralized_target}"
        foreign_key = Map.get(rel, "foreign_key") || "#{rel_name}_id"
        on_delete = map_on_delete_strategy(Map.get(rel, "on_delete", "restrict"))

        "          add :#{foreign_key}, references(:#{target_table}, type: :uuid, on_delete: #{on_delete}), null: true"
      end)

    (field_columns ++ foreign_key_columns) |> Enum.join("\n")
  end

  # 生成外键索引（已包含在列生成中，此函数保留用于将来扩展）
  # defp generate_foreign_keys(_relations, _slug) do
  #   ""
  # end

  # 生成表索引
  defp generate_table_indexes(_fields, relations, indexes_config, table_name) do
    indexes = []

    # 从配置的 indexes 生成
    indexes =
      Enum.reduce(indexes_config, indexes, fn index_config, acc ->
        index_fields = Map.get(index_config, "fields", [])
        index_type = Map.get(index_config, "type", "btree")

        index_name =
          Map.get(index_config, "name") || "#{table_name}_#{Enum.join(index_fields, "_")}_idx"

        where_clause = Map.get(index_config, "where")

        fields_str = Enum.map(index_fields, fn f -> ":#{f}" end) |> inspect()

        index_opts_list =
          [
            if(index_type != "btree", do: "using: \"#{index_type}\"", else: nil),
            if(where_clause, do: "where: \"#{where_clause}\"", else: nil)
          ]
          |> Enum.filter(& &1)

        name_opt = "name: :#{index_name}"
        all_opts = [name_opt | index_opts_list] |> Enum.join(", ")

        index_code =
          if length(index_opts_list) > 0,
            do: "        create index(:#{table_name}, #{fields_str}, #{all_opts})",
            else: "        create index(:#{table_name}, #{fields_str}, #{name_opt})"

        [index_code | acc]
      end)

    # 为外键字段生成索引
    many_to_one_fields =
      relations
      |> Enum.filter(fn rel -> Map.get(rel, "type") == "manyToOne" end)
      |> Enum.map(fn rel ->
        Map.get(rel, "foreign_key") || "#{Map.get(rel, "name")}_id"
      end)

    indexes =
      Enum.reduce(many_to_one_fields, indexes, fn fk_field, acc ->
        ["        create index(:#{table_name}, [:#{fk_field}])" | acc]
      end)

    all_indexes = indexes

    if length(all_indexes) > 0 do
      "\n" <> Enum.join(all_indexes, "\n")
    else
      ""
    end
  end

  # 生成唯一约束
  defp generate_unique_constraints(fields, table_name) do
    unique_fields =
      Enum.filter(fields, fn field -> Map.get(field, "unique", false) end)
      |> Enum.map(fn field -> Map.get(field, "name") end)

    unique_indexes =
      Enum.map(unique_fields, fn field_name ->
        "        create unique_index(:#{table_name}, [:#{field_name}])"
      end)

    if length(unique_indexes) > 0 do
      "\n" <> Enum.join(unique_indexes, "\n")
    else
      ""
    end
  end

  # 将字段类型映射到数据库列类型
  defp map_field_kind_to_column("string", _options), do: ":string"
  defp map_field_kind_to_column("text", _options), do: ":text"
  defp map_field_kind_to_column("integer", _options), do: ":integer"

  defp map_field_kind_to_column("decimal", options) do
    precision = Map.get(options, "precision", 18)
    scale = Map.get(options, "scale", 2)
    ":decimal, precision: #{precision}, scale: #{scale}"
  end

  defp map_field_kind_to_column("boolean", _options), do: ":boolean"
  defp map_field_kind_to_column("date", _options), do: ":date"
  defp map_field_kind_to_column("datetime", _options), do: ":utc_datetime_usec"
  defp map_field_kind_to_column("json", _options), do: ":jsonb"

  defp map_field_kind_to_column("enum", _options) do
    # enum 可以存储为 text 或使用 PostgreSQL enum 类型
    # 简化处理：使用 text
    ":string"
  end

  defp map_field_kind_to_column(_kind, _options), do: ":string"

  # 获取默认值
  defp get_default_value(field, _kind) do
    case Map.get(field, "default") do
      nil -> nil
      value when is_binary(value) -> ~s("#{value}")
      value -> inspect(value)
    end
  end

  # 映射 on_delete 策略
  defp map_on_delete_strategy("cascade"), do: ":delete_all"
  defp map_on_delete_strategy("restrict"), do: ":restrict"
  defp map_on_delete_strategy("set_null"), do: ":nilify_all"
  defp map_on_delete_strategy("no_action"), do: ":nothing"
  defp map_on_delete_strategy(_), do: ":restrict"

  # 生成迁移模块名
  defp create_module_name(slug) do
    slug
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join()
    |> (&"CreateCms#{&1}").()
  end

  # 生成联结表迁移模块名
  defp create_join_table_module_name(source_slug, rel_name) do
    source_part =
      source_slug |> String.split("_") |> Enum.map(&String.capitalize/1) |> Enum.join()

    rel_part = rel_name |> String.split("_") |> Enum.map(&String.capitalize/1) |> Enum.join()
    "CreateCms#{source_part}#{rel_part}Link"
  end

  # 生成时间戳（用于迁移文件名）
  # 使用 Ecto.Migration 的标准格式：YYYYMMDDHHMMSS
  # 确保每次调用都有唯一的时间戳
  defp generate_timestamp do
    # 使用 System.unique_integer 确保唯一性
    # 格式：14位日期时间 + 3位唯一后缀
    {{year, month, day}, {hour, min, sec}} = :calendar.universal_time()

    # 标准格式：YYYYMMDDHHMMSS (14位)
    base_timestamp =
      :io_lib.format("~4..0B~2..0B~2..0B~2..0B~2..0B~2..0B", [year, month, day, hour, min, sec])
      |> IO.chardata_to_string()

    # 添加唯一标识符（使用 System.unique_integer 的后3位）
    unique_suffix =
      System.unique_integer([:positive, :monotonic])
      |> rem(1000)
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    base_timestamp <> unique_suffix
  end
end
