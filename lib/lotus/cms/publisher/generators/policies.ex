defmodule Lotus.CMS.Publisher.Generators.Policies do
  @moduledoc """
  权限策略生成器（占位）
  """

  @doc """
  占位入口，返回 :ok
  """
  def generate(_slug, _config) do
    quote do
      policies do
        policy always() do
          authorize_if(always())
        end
      end
    end
  end
end
