defmodule Lotus.Core.BOMItem do
  @moduledoc false
  @enforce_keys [:product, :quantity, :outsourced]
  @type t :: %__MODULE__{
          product: Lotus.Core.Product.t(),
          quantity: integer(),
          outsourced: boolean()
        }

  defstruct product: nil,
            quantity: nil,
            outsourced: nil

  def new(product, quantity, outsourced) do
    %__MODULE__{
      product: product,
      quantity: quantity,
      outsourced: outsourced
    }
  end
end
