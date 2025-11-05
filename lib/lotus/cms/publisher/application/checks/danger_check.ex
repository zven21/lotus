defmodule Lotus.CMS.Publisher.Checks.DangerCheck do
  @moduledoc """
  Behavior for dangerous change detection on migration plans.

  Implementations should analyze a Plan (and optionally DB stats) and return
  a list of findings with severity and rationale. This is a placeholder.
  """

  @type severity :: :info | :warn | :block
  @type finding :: %{
          required(:severity) => severity,
          required(:reason) => String.t(),
          optional(:hint) => String.t()
        }

  @callback analyze(plan :: map(), stats :: map()) :: [finding]
end
