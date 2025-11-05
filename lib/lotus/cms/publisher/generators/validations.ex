defmodule Lotus.CMS.Publisher.Generators.Validations do
  @moduledoc """
  验证生成器

  职责：
  - 生成字段级验证
  - 生成跨字段验证
  - 生成条件验证
  """

  @doc """
  生成 changeset 验证逻辑
  """
  def generate_changeset_validations(_fields, _config), do: []
end
