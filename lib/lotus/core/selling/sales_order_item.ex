defmodule Lotus.Core.SalesOrderItem do
  @moduledoc """
  Domain model for SalesOrderItem
  """

  alias Lotus.Core.{Variant, Customer}

  @type customer :: Customer.t()
  @type variant :: Variant.t()

  @type t :: %__MODULE__{
          id: binary(),
          variant: variant(),
          customer: customer(),
          quantity: integer(),
          unit_price: integer()
        }

  defstruct id: nil,
            variant: %{},
            unit_price: 0,
            customer: %{},
            amount: 0,
            quantity: 1

  def new(variant, unit_price, quantity, customer) do
    amount = unit_price * quantity
    %__MODULE__{id: Ecto.UUID.generate(), variant: variant, quantity: quantity, unit_price: unit_price, customer: customer, amount: amount}
  end
end
