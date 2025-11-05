defmodule Lotus.CMS.Publisher.Hooks.AuditHook do
  @moduledoc """
  Behavior for audit lifecycle hooks during publish pipeline.

  Placeholder: implementors can persist audit trails around artifact writes.
  """

  @callback before_write(context :: map()) :: :ok | {:error, term()}
  @callback after_write(context :: map()) :: :ok | {:error, term()}
end
