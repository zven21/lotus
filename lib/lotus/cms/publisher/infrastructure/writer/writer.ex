defmodule Lotus.CMS.Publisher.Writer do
  @moduledoc """
  Behavior for writing generated artifacts to storage (filesystem, etc.).
  """

  @type artifact :: %{required(:filename) => String.t(), required(:content) => iodata()}
  @type checksums :: %{optional(atom()) => String.t()}

  @callback write(artifacts :: [artifact], opts :: keyword()) ::
              {:ok, paths :: [String.t()], checksums} | {:error, term()}
end
