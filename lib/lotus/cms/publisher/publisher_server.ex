defmodule Lotus.CMS.PublisherServer do
  @moduledoc """
  GenServer that ensures Publisher prerequisites are created at application startup.

  This server runs early in the supervision tree (before Phoenix Endpoint) to ensure:
  - Generated domain placeholder exists
  - GraphQL types aggregator placeholder exists
  - DataFieldResolver placeholder exists

  Without these placeholders, compilation may fail when other modules try to reference them.

  ## Future Extensions

  This server can be extended to:
  - Watch config files for changes and trigger republishing
  - Provide health check endpoints
  - Cache generated module information
  """

  use GenServer

  require Logger

  ## Client API

  @doc """
  Starts the PublisherServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Server callbacks

  @impl true
  def init(_opts) do
    Logger.info("🚀 PublisherServer: Starting...")

    # Ensure placeholders synchronously during init
    # This must complete before returning {:ok, state} to prevent race conditions
    case ensure_placeholders_safe() do
      :ok ->
        Logger.info("✅ PublisherServer: All placeholders ensured successfully")
        {:ok, %{placeholders_ensured: true}, {:continue, :post_boot}}

      {:error, reason} ->
        # Log error but don't crash - allow app to start and show errors
        Logger.error("⚠️  PublisherServer: Failed to ensure placeholders: #{inspect(reason)}")

        Logger.warning(
          "⚠️  PublisherServer: Application will continue, but some features may not work"
        )

        {:ok, %{placeholders_ensured: false, error: reason}, {:continue, :post_boot}}
    end
  end

  @impl true
  def handle_continue(:post_boot, state) do
    # Reserved for future async boot tasks (e.g., watching config files)
    # Can add FileSystem watcher here if needed
    {:noreply, state}
  end

  # Private helpers

  defp ensure_placeholders_safe do
    try do
      Lotus.CMS.Publisher.ensure_placeholders()
      :ok
    rescue
      error ->
        {:error, {:exception, error, __STACKTRACE__}}
    catch
      :exit, reason ->
        {:error, {:exit, reason}}

      kind, reason ->
        {:error, {:throw, kind, reason}}
    end
  end
end
