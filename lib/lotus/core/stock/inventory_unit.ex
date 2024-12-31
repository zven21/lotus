defmodule Lotus.Core.InventoryUnit do
  @moduledoc false

  alias Lotus.Core.{ShipmentOrder, StockLocation, SalesOrderItem, Variant}

  @enforce_keys [:id, :variant, :order_item, :quantity, :shipment_order]

  @type t :: %__MODULE__{
          id: binary(),
          variant: Variant.t(),
          order_item: SalesOrderItem.t(),
          quantity: integer(),
          shipment_order: ShipmentOrder.t(),
          stock_location: StockLocation.t()
        }

  defstruct id: nil,
            variant: nil,
            order_item: nil,
            quantity: 0,
            shipment_order: nil,
            stock_location: nil

  def new(id, order_item, quantity, shipment_order, stock_location) do
    %__MODULE__{
      id: id,
      variant: order_item.variant,
      order_item: order_item,
      quantity: quantity,
      shipment_order: shipment_order,
      stock_location: stock_location
    }
  end
end
