defmodule Lotus.Core.SalesOrder do
  @moduledoc """
  Domain model for Sales Order
  """

  alias Lotus.Core.{PaymentOrder, ShipmentOrder, InventoryUnit, Customer, SalesOrderItem}
  import Ecto.UUID

  @enforce_keys [:id, :customer, :order_items]

  @type order_item :: SalesOrderItem.t()
  @type shipment_order :: ShipmentOrder.t()
  @type payment_order :: PaymentOrder.t()
  @type inventory_unit :: InventoryUnit.t()
  @type customer :: Customer.t()

  @type t :: %__MODULE__{
          id: binary(),
          customer: customer(),
          order_items: %{
            binary() => order_item()
          },
          shipment_orders: %{
            binary() => shipment_order()
          },
          payment_orders: %{
            binary() => payment_order()
          },
          inventory_units: %{
            binary() => inventory_unit()
          }
        }

  defstruct id: nil,
            customer: %{},
            payment_amount: 0,
            state: :pending,
            payment_state: :pending,
            shipment_state: :pending,
            order_items: %{},
            payment_orders: %{},
            shipment_orders: %{},
            inventory_units: %{}

  def add_cart(%{customer: customer, variants: variants}) do
    order_items =
      Enum.reduce(variants, %{}, fn variant, acc ->
        item = SalesOrderItem.new(variant, variant.selling_price, 10, customer)
        Map.put(acc, variant.id, item)
      end)

    payment_amount =
      order_items
      |> Map.values()
      |> Enum.map(& &1.amount)
      |> Enum.sum()

    %__MODULE__{
      id: generate(),
      payment_amount: payment_amount,
      state: :cart,
      payment_state: :pending,
      shipment_state: :pending,
      customer: customer,
      order_items: order_items
    }
  end

  def place(order) do
    {shipment_orders, inventory_units} =
      Enum.reduce(order.order_items, {%{}, %{}}, fn {_variant_id, order_item}, {acc_shipment_orders, acc_inventory_units} ->
        {new_shipment_orders, new_inventory_units, _} =
          Enum.reduce_while(order_item.variant.stock_items, {acc_shipment_orders, acc_inventory_units, order_item.quantity}, fn {_stock_item_id, stock_item},
                                                                                                                                {shipment_orders, inventory_units, remaining_quantity} ->
            available_quantity = stock_item.quantity
            to_ship_quantity = min(available_quantity, remaining_quantity)
            new_remaining_quantity = remaining_quantity - to_ship_quantity

            stock_location = stock_item.stock_location

            # 创建 ShipmentOrder
            {shipment_order, new_shipment_orders} =
              if Map.has_key?(shipment_orders, stock_location.id) do
                {shipment_orders[stock_location.id], shipment_orders}
              else
                new_shipment_order = ShipmentOrder.new(order.customer, stock_location)
                {new_shipment_order, Map.put(shipment_orders, stock_location.id, new_shipment_order)}
              end

            # 创建 InventoryUnit
            inventory_unit_id = generate()

            inventory_unit =
              InventoryUnit.new(
                inventory_unit_id,
                order_item,
                to_ship_quantity,
                shipment_order,
                stock_location
              )

            new_inventory_units = Map.put(inventory_units, inventory_unit_id, inventory_unit)

            if new_remaining_quantity == 0 do
              {:halt, {new_shipment_orders, new_inventory_units, new_remaining_quantity}}
            else
              {:cont, {new_shipment_orders, new_inventory_units, new_remaining_quantity}}
            end
          end)

        {new_shipment_orders, new_inventory_units}
      end)

    payment_order_id = generate()

    payment_order =
      PaymentOrder.new(
        order.payment_amount,
        :pending
      )

    %{order | state: :placed, shipment_orders: shipment_orders, payment_orders: %{payment_order_id => payment_order}, inventory_units: inventory_units}
  end

  def pay(order) do
    updated_payment_orders =
      Enum.map(order.payment_orders, fn {id, payment_order} ->
        {id, %{payment_order | state: :paid}}
      end)
      |> Enum.into(%{})

    %{order | state: do_order_state(:paid, order.shipment_state), payment_state: :paid, payment_orders: updated_payment_orders}
  end

  def ship(order) do
    updated_shipment_orders =
      Enum.map(order.shipment_orders, fn {id, shipment_order} ->
        {id, %{shipment_order | state: :shipped}}
      end)
      |> Enum.into(%{})

    %{order | state: do_order_state(order.payment_state, :shipped), shipment_state: :shipped, shipment_orders: updated_shipment_orders}
  end

  defp do_order_state(:paid, :shipped), do: :completed
  defp do_order_state(_, :shipped), do: :shipped
  defp do_order_state(:paid, _), do: :paid
  defp do_order_state(_, _), do: :placed
end
