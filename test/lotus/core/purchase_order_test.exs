defmodule Lotus.Core.PurchaseOrderTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import Ecto.UUID
  alias Lotus.Core.{PurchaseOrder, PurchaseOrderItem, Supplier}

  setup do
    supplier = %Supplier{id: generate(), name: "Test Supplier", contact_info: "test@example.com"}
    %{supplier: supplier}
  end

  test "create and place a purchase order", %{supplier: supplier} do
    variant = %{id: generate()}
    order_item = PurchaseOrderItem.new(variant, 10.0, 5)
    purchase_order = PurchaseOrder.new(supplier, %{order_item.id => order_item})

    placed_order = PurchaseOrder.place(purchase_order)

    assert placed_order.state == :placed
    assert map_size(placed_order.payment_orders) == 1

    [payment_order] = Map.values(placed_order.payment_orders)
    assert payment_order.amount == 50.0
    assert payment_order.state == :pending
  end

  test "pay a purchase order", %{supplier: supplier} do
    variant = %{id: generate()}
    order_item = PurchaseOrderItem.new(variant, 10.0, 5)
    purchase_order = PurchaseOrder.new(supplier, %{order_item.id => order_item})
    placed_order = PurchaseOrder.place(purchase_order)

    paid_order = PurchaseOrder.pay(placed_order)

    assert paid_order.state == :paid
    assert paid_order.payment_state == :paid

    [payment_order] = Map.values(paid_order.payment_orders)
    assert payment_order.state == :paid
  end

  test "deliver a purchase order", %{supplier: supplier} do
    variant = %{id: generate()}
    order_item = PurchaseOrderItem.new(variant, 10.0, 5)
    purchase_order = PurchaseOrder.new(supplier, %{order_item.id => order_item})
    placed_order = PurchaseOrder.place(purchase_order)
    paid_order = PurchaseOrder.pay(placed_order)

    delivered_order = PurchaseOrder.deliver(paid_order)

    assert delivered_order.state == :completed
    assert delivered_order.delivery_state == :delivered
  end
end
