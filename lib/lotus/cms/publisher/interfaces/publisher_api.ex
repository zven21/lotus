defmodule Lotus.CMS.Publisher.API do
  @moduledoc """
  Stable facade API for Publisher. Delegates to `Lotus.CMS.Publisher` for now.

  This module provides a consistent external interface while we refactor
  internals into application/domain/infrastructure layers.
  """

  alias Lotus.CMS.Publisher

  @doc "Publish all content types using current database definitions and/or configs."
  defdelegate publish_all(opts \\ []), to: Publisher

  @doc "Publish content types from manifests under priv/cms/*.json."
  defdelegate publish_from_manifests(opts \\ []), to: Publisher

  @doc "Publish a single slug. Reads config files (json/yaml) for that slug."
  defdelegate publish_slug(slug, opts \\ []), to: Publisher

  @doc "Publish a single slug from config files (explicit entrypoint)."
  defdelegate publish_slug_from_config(slug, opts \\ []), to: Publisher

  @doc "Publish all from a config directory."
  defdelegate publish_from_config_files(opts \\ []), to: Publisher

  @doc "Write GraphQL types aggregator for generated resources."
  defdelegate write_graphql_types_aggregator(), to: Publisher

  @doc "End-to-end: build from DB, generate and (optionally) run migrations, publish resources."
  defdelegate publish_from_database_with_migrations(opts \\ []), to: Publisher

  @doc "Build a config map from database projections for given slug."
  defdelegate build_config_from_database(slug), to: Publisher

  @doc "Persist a config snapshot to disk (JSON)."
  defdelegate save_config_snapshot_file(slug, config, dir \\ nil), to: Publisher

  @doc "Get previously published config for a slug (from DB)."
  defdelegate get_published_config(slug), to: Publisher

  @doc "Set previously published config for a slug (into DB)."
  defdelegate set_published_config(slug, config), to: Publisher
end
