defmodule Lotus.Core.SubcontractingOrder do
  @moduledoc false

  @enforce_keys [:id, :product, :supplier, :components, :steps, :due_date]
  @type component :: %{
          component_id: binary(),
          quantity: integer()
        }
  @type step :: %{
          step_id: binary(),
          name: binary(),
          description: binary(),
          operation: binary()
        }
  @type t :: %__MODULE__{
          id: binary(),
          product: Lotus.Core.Product.t(),
          supplier: Lotus.Core.Supplier.t(),
          components: %{binary() => component()},
          steps: %{binary() => step()},
          due_date: DateTime.t()
        }

  defstruct id: nil,
            product: nil,
            supplier: nil,
            components: %{},
            steps: %{},
            due_date: nil

  def new(id, product, supplier, components, steps, due_date) do
    %__MODULE__{
      id: id,
      product: product,
      supplier: supplier,
      components: components,
      steps: steps,
      due_date: due_date
    }
  end
end
