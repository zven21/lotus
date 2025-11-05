defmodule Lotus.CMS.Publisher.Generators.Search do
  @moduledoc """
  搜索生成器

  职责：
  - 生成搜索 prepare 函数
  - 支持全文搜索、模糊搜索
  - 支持字段加权搜索
  """

  @doc """
  生成 read 动作的 prepare 函数（占位）
  """
  def generate_prepare_fn(_slug, _fields, _search_config, _filtering_config), do: :ok

  # 占位文件：目前不实现任何逻辑
end
