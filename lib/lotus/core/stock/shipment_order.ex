defmodule Lotus.Core.ShipmentOrder do
  @moduledoc """
  Domain model for ShipmentOrder
  """

  @enforce_keys [:id, :customer]

  @type customer :: Lotus.Core.Customer.t()
  @type stock_location :: Lotus.Core.StockLocation.t()

  @type t :: %__MODULE__{
          id: binary(),
          state: binary(),
          customer: customer(),
          stock_location: stock_location()
        }

  defstruct id: nil,
            state: :pending,
            customer: %{},
            stock_location: %{}

  def new(customer, stock_location) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      state: :pending,
      customer: customer,
      stock_location: stock_location
    }
  end
end
