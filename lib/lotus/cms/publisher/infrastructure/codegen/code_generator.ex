defmodule Lotus.CMS.Publisher.Codegen.CodeGenerator do
  @moduledoc """
  Behavior for code generation targets used by the publisher pipeline.

  Targets can include :ecto_migration, :ash_resource, :policies, :search_index, etc.
  """

  @type artifact :: %{required(:filename) => String.t(), required(:content) => iodata()}

  @callback generate(target :: atom(), plan_or_config :: map(), opts :: keyword()) ::
              {:ok, [artifact]} | {:error, term()}
end
