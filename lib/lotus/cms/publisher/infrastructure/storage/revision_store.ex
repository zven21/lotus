defmodule Lotus.CMS.Publisher.Storage.RevisionStore do
  @moduledoc """
  Behavior for persisting publish revisions (config/plan/artifacts/checksums).

  Placeholder behavior; provide an Ecto-backed implementation later.
  """

  @type revision :: %{
          required(:id) => any(),
          required(:slug) => String.t(),
          required(:config_checksum) => String.t(),
          required(:plan_checksum) => String.t(),
          required(:artifact_checksum) => String.t(),
          optional(:status) => String.t(),
          optional(:meta) => map()
        }

  @callback save_revision(revision) :: {:ok, revision} | {:error, term()}
  @callback get_revision(id :: any()) :: {:ok, revision} | {:error, :not_found}
  @callback list_revisions(slug :: String.t()) :: [revision]
end
