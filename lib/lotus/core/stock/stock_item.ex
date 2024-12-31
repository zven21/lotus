defmodule Lotus.Core.StockItem do
  @moduledoc """
  Domain model for StockItem
  """

  @enforce_keys [:variant, :stock_location, :quantity]

  @type t :: %__MODULE__{
          id: binary(),
          variant: Lotus.Core.Variant.t(),
          stock_location: Lotus.Core.StockLocation.t(),
          quantity: non_neg_integer()
        }

  defstruct [
    :id,
    :variant,
    :stock_location,
    :quantity
  ]

  @doc """
  Create a new StockItem instance.

  ## Returns
  - A new `StockItem` struct if the request has the required fields.
  """
  def new(variant, stock_location, quantity) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      variant: variant,
      stock_location: stock_location,
      quantity: quantity
    }
  end
end
