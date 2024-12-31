defmodule Lotus.Core.PurchaseOrderItem do
  @moduledoc """
  Domain model from PurchaseOrderItem
  """

  alias Lumina.Core.Variant

  @enforce_keys [:id, :variant, :unit_price, :quantity]

  @type t :: %__MODULE__{
          id: binary(),
          variant: Variant.t(),
          unit_price: number(),
          quantity: non_neg_integer()
        }

  defstruct id: nil,
            variant: nil,
            unit_price: 0,
            quantity: 0

  def new(variant, unit_price, quantity) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      variant: variant,
      unit_price: unit_price,
      quantity: quantity
    }
  end
end
