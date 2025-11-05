defmodule Lotus.CMS.Publisher.Hooks.DraftPublishHook do
  @moduledoc """
  Behavior for draft publish approval/promote hooks.

  Placeholder: implementors can integrate with UI approval or notifications.
  """

  @callback before_approve(context :: map()) :: :ok | {:error, term()}
  @callback after_promote(context :: map()) :: :ok | {:error, term()}
end
