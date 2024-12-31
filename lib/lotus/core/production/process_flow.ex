defmodule Lotus.Core.ProcessFlow do
  @moduledoc """
  # The `ProcessFlow` struct defines the manufacturing steps for a product.
  # It has an identifier (`id`) and a map of `steps`.
  # Each key in the `steps` map is a unique identifier for the step,
  # and the value is a struct containing step - related information such as name,
  # description, operation, and whether it is outsourced and the associated supplier.
  """

  @enforce_keys [:id, :steps]
  @type step :: %{
          step_id: binary(),
          name: binary(),
          description: binary(),
          operation: binary(),
          outsourced: boolean(),
          supplier: Supplier.t() | nil
        }
  @type t :: %__MODULE__{
          id: binary(),
          steps: %{binary() => step()}
        }

  defstruct id: nil,
            steps: %{}

  @doc """
  Creates a new `ProcessFlow` instance.

  - `id` is the unique identifier for the process flow.
  - `steps` is a map that defines all the manufacturing steps of the product.
  """
  def new(id, steps) do
    %__MODULE__{
      id: id,
      steps: steps
    }
  end
end
