defmodule Lotus.CMS.ConfigMonitor do
  @moduledoc """
  GenServer that monitors configuration files and hot-reloads resources.

  When config files change, it automatically:
  1. Recompiles the affected resources
  2. Reloads them in the running application
  3. Updates the domain registration
  """

  use GenServer
  require Logger

  @config_dir Path.join([File.cwd!(), "priv", "cms", "config"])
  # 2 seconds
  @check_interval 2000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def check_now do
    GenServer.cast(__MODULE__, :check_files)
  end

  def reload_config do
    GenServer.cast(__MODULE__, :reload)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    Process.send_after(self(), :check, @check_interval)

    state = %{
      last_check: System.system_time(:second),
      file_checksums: %{},
      opts: opts
    }

    Logger.info("🔍 Lotus CMS ConfigMonitor started, watching: #{@config_dir}")

    {:ok, state}
  end

  @impl true
  def handle_info(:check, state) do
    # 检查文件是否有变化
    current_checksums = get_file_checksums()
    changed_files = detect_changes(state.file_checksums, current_checksums)

    if length(changed_files) > 0 do
      Logger.info("📝 Config files changed: #{inspect(changed_files)}")
      reload_and_notify(changed_files)
      {:noreply, %{state | file_checksums: current_checksums}}
    else
      Process.send_after(self(), :check, @check_interval)
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast(:check_files, state) do
    current_checksums = get_file_checksums()
    changed_files = detect_changes(state.file_checksums, current_checksums)

    if length(changed_files) > 0 do
      Logger.info("📝 Config files changed: #{inspect(changed_files)}")
      reload_and_notify(changed_files)
      {:noreply, %{state | file_checksums: current_checksums}}
    else
      {:noreply, %{state | file_checksums: current_checksums}}
    end
  end

  @impl true
  def handle_cast(:reload, state) do
    Logger.info("🔄 Manual reload triggered")
    reload_all()
    {:noreply, state}
  end

  # Private functions

  defp get_file_checksums do
    File.mkdir_p!(@config_dir)

    @config_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, [".json", ".yaml", ".yml"]))
    |> Enum.map(&Path.join(@config_dir, &1))
    |> Enum.map(fn path ->
      try do
        stat = File.stat!(path)
        {path, stat.mtime, stat.size}
      rescue
        File.Error -> {path, 0, 0}
      end
    end)
    |> Enum.into(%{}, fn {path, mtime, size} -> {path, {mtime, size}} end)
  end

  defp detect_changes(old_checksums, new_checksums) do
    # 找出新增或修改的文件
    new_files =
      Map.keys(new_checksums)
      |> Enum.filter(fn path ->
        old_val = Map.get(old_checksums, path)
        old_val != Map.get(new_checksums, path)
      end)

    new_files
  end

  defp reload_and_notify(_changed_files) do
    Logger.info("🔄 Reloading affected resources...")

    try do
      # 重新发布所有配置
      Lotus.CMS.Publisher.publish_from_config_files()

      # 通知 Phoenix 重新加载
      notify_phoenix_reload()

      Logger.info("✅ Resources reloaded successfully")
    rescue
      error ->
        Logger.error("❌ Failed to reload resources: #{inspect(error)}")
    end
  end

  defp reload_all do
    Logger.info("🔄 Reloading all resources...")

    try do
      Lotus.CMS.Publisher.publish_from_config_files()
      notify_phoenix_reload()
      Logger.info("✅ All resources reloaded")
    rescue
      error ->
        Logger.error("❌ Reload failed: #{inspect(error)}")
    end
  end

  # 通知 Phoenix Live Reload
  defp notify_phoenix_reload do
    # 尝试触发 Phoenix Live Reload
    if Code.ensure_loaded?(Phoenix.CodeReloader) do
      Phoenix.CodeReloader.reload!(LotusWeb.Endpoint, [])
    end
  end
end
