defmodule Lotus.CMS.Publisher.Hooks.VersioningHook do
  @moduledoc """
  Behavior for versioning snapshot hooks.

  Placeholder: implementors can snapshot config/plan/artifacts per revision.
  """

  @callback on_revision(revision :: map()) :: :ok | {:error, term()}
end
