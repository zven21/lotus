defmodule Lotus.Core.BOM do
  @moduledoc """
  # The `BOM` (Bill of Materials) struct holds information about the components
  # required to manufacture a product.
  # It has an identifier (`id`) and a map of `components`.
  # Each key in the `components` map is a unique identifier for the component,
  # and the value is a `BOMItem` struct.
  """

  alias Lotus.Core.BOMItem

  @enforce_keys [:id, :components]
  @type component :: %{
          component_id: binary(),
          quantity: integer(),
          outsourced: boolean()
        }
  @type t :: %__MODULE__{
          id: binary(),
          components: %{binary() => BOMItem.t()}
        }

  defstruct id: nil,
            components: %{}

  @doc """
  Creates a new `BOM` instance.

  - `id` is the unique identifier for the BOM.
  - `components` is a map where each entry represents a component in the BOM.

  """
  def new(id, components) do
    %__MODULE__{
      id: id,
      components: components
    }
  end
end
