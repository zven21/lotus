defmodule Lotus.Core.BOMItem do
  @moduledoc """
  # The `BOMItem` struct represents an item in the Bill of Materials.
  # It contains a reference to the `product` (which can be a raw material, semi finished good, etc.),
  # the quantity of the product required, and a flag indicating if it is outsourced.
  """

  @enforce_keys [:product, :quantity, :outsourced]

  @type t :: %__MODULE__{
          product: Lotus.Core.Product.t(),
          quantity: integer(),
          outsourced: boolean()
        }

  defstruct product: nil,
            quantity: nil,
            outsourced: nil

  @doc """
  Creates a new `BOMItem` instance.

  - `product` is the product associated with this BOM item.
  - `quantity` is the number of this product needed in the BOM.
  - `outsourced` indicates whether this item is produced by an external supplier.
  """
  def new(product, quantity, outsourced) do
    %__MODULE__{
      product: product,
      quantity: quantity,
      outsourced: outsourced
    }
  end
end
