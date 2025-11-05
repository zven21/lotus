defmodule Lotus.CMS.Publisher.Snapshot do
  @moduledoc """
  配置快照持久化：按 slug 保存/加载最新已发布的 config。
  存储位置：priv/cms/snapshots/<slug>.json
  """

  @base_dir Path.join([File.cwd!(), "priv", "cms", "snapshots"])

  @spec read_latest(String.t()) :: {:ok, map()} | {:error, term()}
  def read_latest(slug) do
    File.mkdir_p!(@base_dir)
    path = Path.join(@base_dir, slug <> ".json")

    if File.exists?(path) do
      with {:ok, bin} <- File.read(path), {:ok, cfg} <- Jason.decode(bin) do
        {:ok, cfg}
      else
        error -> error
      end
    else
      {:error, :not_found}
    end
  end

  @spec write_latest(String.t(), map()) :: :ok | {:error, term()}
  def write_latest(slug, config) when is_map(config) do
    File.mkdir_p!(@base_dir)
    path = Path.join(@base_dir, slug <> ".json")

    case Jason.encode(config, pretty: true) do
      {:ok, bin} -> File.write(path, bin)
      error -> error
    end
  end
end
