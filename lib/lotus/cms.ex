defmodule Lotus.CMS do
  @moduledoc """
  CMS 上下文，封装 Ash 资源的常用调用。
  """
  alias Lotus.CMS.AshDomain
  alias Ash.Query
  require Ash.Query

  @doc """
  列出所有 ContentType（简单演示）
  """
  def list_content_types do
    Lotus.CMS.Ash.ContentType
    |> Query.new()
    |> Ash.read!(domain: AshDomain)
  end
end
