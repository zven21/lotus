defmodule Lotus.Core.SalesOrderTest do
  use ExUnit.Case

  alias Lotus.Core.{SalesOrder, Customer, SalesOrderItem, Variant, StockLocation}
  import Ecto.UUID

  setup do
    customer = %Customer{id: generate()}
    %{customer: customer}
  end

  test "add_cart creates valid SalesOrder", %{customer: customer} do
    variant1 = %Variant{id: generate(), name: "Product 1", selling_price: 10.0}
    variant2 = %Variant{id: generate(), name: "Product 2", selling_price: 20.0}
    variants = [variant1, variant2]

    sales_order = SalesOrder.add_cart(%{customer: customer, variants: variants})

    assert sales_order.id != nil
    assert sales_order.customer == customer
    assert sales_order.state == :cart
    assert sales_order.payment_state == :pending
    assert sales_order.shipment_state == :pending

    # assert Map.keys(sales_order.order_items) == Enum.map(variants, & &1.id)
    total_amount = Enum.sum(Enum.map(variants, & &1.selling_price)) * 10
    assert sales_order.payment_amount == total_amount
  end

  describe "place" do
    test "place method with one warehouse purchase", %{customer: customer} do
      variant = %Variant{
        id: generate(),
        name: "Test Product",
        description: "A test product",
        selling_price: 10.0,
        stock_items: %{
          "warehouse1" => %{
            id: "warehouse1",
            variant: nil,
            stock_location: %StockLocation{id: "warehouse1", name: "Warehouse 1"},
            quantity: 100
          }
        }
      }

      order_item = SalesOrderItem.new(variant, variant.selling_price, 50, customer)

      sales_order = %SalesOrder{
        id: generate(),
        customer: customer,
        order_items: %{variant.id => order_item},
        payment_amount: 500.0,
        state: :pending,
        payment_state: :pending,
        shipment_state: :pending
      }

      placed_order = SalesOrder.place(sales_order)

      assert map_size(placed_order.shipment_orders) == 1
      assert map_size(placed_order.inventory_units) == 1

      [shipment_order] = Map.values(placed_order.shipment_orders)
      [inventory_unit] = Map.values(placed_order.inventory_units)

      assert inventory_unit.quantity == 50
      assert inventory_unit.stock_location.id == "warehouse1"
      assert inventory_unit.shipment_order == shipment_order
    end

    test "place method with two warehouse purchase", %{customer: customer} do
      variant = %Variant{
        id: generate(),
        name: "Test Product",
        description: "A test product",
        selling_price: 10.0,
        stock_items: %{
          "warehouse1" => %{
            id: "warehouse1",
            variant: nil,
            stock_location: %StockLocation{id: "warehouse1", name: "Warehouse 1"},
            quantity: 50
          },
          "warehouse2" => %{
            id: "warehouse2",
            variant: nil,
            stock_location: %StockLocation{id: "warehouse2", name: "Warehouse 2"},
            quantity: 70
          }
        }
      }

      order_item = SalesOrderItem.new(variant, variant.selling_price, 100, customer)

      sales_order = %SalesOrder{
        id: generate(),
        customer: customer,
        order_items: %{variant.id => order_item},
        payment_amount: 1000.0,
        state: :pending,
        payment_state: :pending,
        shipment_state: :pending
      }

      placed_order = SalesOrder.place(sales_order)

      assert map_size(placed_order.shipment_orders) == 2
      assert map_size(placed_order.inventory_units) == 2

      inventory_units = Map.values(placed_order.inventory_units)
      inventory_unit_1 = Enum.find(inventory_units, fn unit -> unit.stock_location.id == "warehouse1" end)
      inventory_unit_2 = Enum.find(inventory_units, fn unit -> unit.stock_location.id == "warehouse2" end)

      assert inventory_unit_1.quantity == 50
      assert inventory_unit_2.quantity == 50
    end
  end

  describe "pay" do
    test "pay method updates payment states", %{customer: customer} do
      variant = %Variant{
        id: generate(),
        name: "Test Product",
        description: "A test product",
        selling_price: 10.0,
        stock_items: %{
          "warehouse1" => %{
            id: "warehouse1",
            variant: nil,
            stock_location: %StockLocation{id: "warehouse1", name: "Warehouse 1"},
            quantity: 100
          }
        }
      }

      order_item = SalesOrderItem.new(variant, variant.selling_price, 10, customer)

      sales_order = %SalesOrder{
        id: generate(),
        customer: customer,
        order_items: %{variant.id => order_item},
        payment_amount: 100.0,
        state: :pending,
        payment_state: :pending,
        shipment_state: :pending
      }

      placed_order = SalesOrder.place(sales_order)
      paid_order = SalesOrder.pay(placed_order)

      [payment_order] = Map.values(paid_order.payment_orders)
      assert payment_order.state == :paid
      assert paid_order.state == :paid
      assert paid_order.payment_state == :paid
    end
  end

  describe "ship" do
    test "ship method updates shipment states", %{customer: customer} do
      variant = %Variant{
        id: generate(),
        name: "Test Product",
        description: "A test product",
        selling_price: 10.0,
        stock_items: %{
          "warehouse1" => %{
            id: "warehouse1",
            variant: nil,
            stock_location: %StockLocation{id: "warehouse1", name: "Warehouse 1"},
            quantity: 100
          }
        }
      }

      order_item = SalesOrderItem.new(variant, variant.selling_price, 10, customer)

      sales_order = %SalesOrder{
        id: generate(),
        customer: customer,
        order_items: %{variant.id => order_item},
        payment_amount: 100.0,
        state: :pending,
        payment_state: :pending,
        shipment_state: :pending
      }

      placed_order = SalesOrder.place(sales_order)
      shipped_order = SalesOrder.ship(placed_order)

      assert shipped_order.shipment_state == :shipped

      Enum.each(Map.values(shipped_order.shipment_orders), fn shipment_order ->
        assert shipment_order.state == :shipped
      end)
    end
  end
end
