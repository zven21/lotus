defmodule Lotus.CMS.Publisher.MigrationCodegen do
  @moduledoc """
  将 MigrationPlan 转为 Ecto.Migration change/0 代码片段，并提供 checksum。
  """

  @spec to_ecto_change(%{table: String.t(), operations: list()}) :: String.t()
  def to_ecto_change(%{table: table, operations: ops}) do
    {has_create, add_ops, other_ops} = partition_ops(ops)

    create_block =
      if has_create do
        create_add_lines =
          Enum.flat_map(add_ops, fn
            {:add_column, field, {:references, target_table, type, opts}} ->
              [
                indent(
                  ~s|add :#{field}, references(:#{target_table}, type: :#{type}, on_delete: :#{Keyword.get(opts, :on_delete, :restrict)})|,
                  4
                )
              ]

            {:add_column, field, type} ->
              [indent(~s|add :#{field}, :#{type}|, 4)]
          end)

        [
          indent(~s|create table(:#{table}, primary_key: false) do|, 2),
          indent(~s|add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")|, 4)
        ] ++
          create_add_lines ++
          [
            indent(~s|timestamps(type: :utc_datetime_usec)|, 4),
            indent("end", 2)
          ]
      else
        []
      end

    body_lines =
      other_ops
      |> Enum.reduce(create_block, fn op, acc -> acc ++ emit_op(table, op) end)
      |> Enum.join("\n")

    """
    def change do
    #{indent(body_lines, 2)}
    end
    """
    |> String.trim()
  end

  defp partition_ops(ops) do
    has_create = Enum.any?(ops, &match?({:create_table}, &1))
    add_ops = if has_create, do: Enum.filter(ops, &match?({:add_column, _, _}, &1)), else: []

    other_ops =
      if has_create do
        ops
        |> Enum.reject(&match?({:add_column, _, _}, &1))
        |> Enum.reject(&match?({:create_table}, &1))
      else
        ops
      end

    {has_create, add_ops, other_ops}
  end

  defp emit_op(_table, {:create_table}), do: []

  defp emit_op(table, {:rename_column, from, to}) do
    [indent(~s|rename table(:#{table}), :#{from}, to: :#{to}|, 2)]
  end

  defp emit_op(table, {:create_unique_index, fields, name}) do
    [indent(~s|create unique_index(:#{table}, #{inspect(fields)}, name: :#{name})|, 2)]
  end

  defp emit_op(table, {:drop_unique_index, fields, name}) do
    [indent(~s|drop_if_exists unique_index(:#{table}, #{inspect(fields)}, name: :#{name})|, 2)]
  end

  defp emit_op(table, {:add_column, field, {:references, target_table, type, opts}}) do
    [
      indent(~s|alter table(:#{table}) do|, 2),
      indent(
        ~s|add :#{field}, references(:#{target_table}, type: :#{type}, on_delete: :#{Keyword.get(opts, :on_delete, :restrict)})|,
        4
      ),
      indent("end", 2),
      indent(~s|create index(:#{table}, [:#{field}])|, 2)
    ]
  end

  defp emit_op(table, {:add_index, fields}) do
    [indent(~s|create index(:#{table}, #{inspect(fields)})|, 2)]
  end

  defp emit_op(table, {:add_column, field, type}) do
    [
      indent(~s|alter table(:#{table}) do|, 2),
      indent(~s|add :#{field}, :#{type}|, 4),
      indent("end", 2)
    ]
  end

  defp emit_op(table, {:drop_column, field}) do
    [
      indent(~s|alter table(:#{table}) do|, 2),
      indent(~s|remove :#{field}|, 4),
      indent("end", 2)
    ]
  end

  defp emit_op(table, {:alter_column_type, field, type}) do
    [
      indent(~s|alter table(:#{table}) do|, 2),
      indent(~s|modify :#{field}, :#{type}|, 4),
      indent("end", 2)
    ]
  end

  defp indent(line, n) when is_binary(line), do: String.duplicate(" ", n) <> line

  @spec checksum(map()) :: String.t()
  def checksum(plan) when is_map(plan) do
    plan
    |> :erlang.term_to_binary()
    |> (&:crypto.hash(:sha256, &1)).()
    |> Base.encode16(case: :lower)
  end
end
