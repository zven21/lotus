defmodule Lotus.CMS.Publisher.Generators.GraphQL do
  @moduledoc """
  GraphQL 类型生成器

  职责：
  - 生成 GraphQL 数据对象类型
  - 生成类型聚合模块
  - 管理生成的类型文件
  """

  require Lotus.DynamicModule

  @doc """
  发布 GraphQL 类型定义

  说明：在强类型列（每类型独立表）模式下，不再生成 `*_data` 动态对象类型，
  由资源字段直接暴露到 GraphQL。此函数保留为兼容入口，当前不进行任何生成。
  """
  def publish_types(_slug, _fields, _opts \\ []) do
    :ok
  end

  @doc """
  生成 GraphQL 数据对象类型
  """
  def generate_data_object_type(_slug, _fields), do: nil

  # 已移除未使用的 generate_field_definition/1

  @doc """
  写入类型聚合模块（GeneratedTypes）

  扫描 generated 目录下的所有类型文件，生成聚合模块

  使用直接文件写入而不是宏，以确保在运行时正确更新
  """
  def write_types_aggregator, do: :ok

  # 从文件中提取模块名
  # 已移除未使用的 extract_module_name_from_file/1

  # 已移除未使用的 kind_to_scalar_type/1
end
