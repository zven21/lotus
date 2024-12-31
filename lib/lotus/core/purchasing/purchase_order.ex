defmodule Lotus.Core.PurchaseOrder do
  @moduledoc """
  Domain model for PurchaseOrder
  """

  import Ecto.UUID
  alias Lotus.Core.{PurchaseOrderItem, Supplier, PaymentOrder}

  @enforce_keys [:id, :supplier, :order_items]

  @type order_item :: PurchaseOrderItem.t()
  @type payment_order :: PaymentOrder.t()
  @type supplier :: Supplier.t()

  @type t :: %__MODULE__{
          id: binary(),
          supplier: supplier(),
          order_items: %{
            binary() => order_item()
          },
          payment_orders: %{
            binary() => payment_order()
          },
          state: atom(),
          payment_state: atom(),
          delivery_state: atom()
        }

  defstruct id: nil,
            supplier: %{},
            order_items: %{},
            payment_orders: %{},
            state: :pending,
            payment_state: :pending,
            delivery_state: :pending

  def new(supplier, order_items) do
    %__MODULE__{
      id: generate(),
      supplier: supplier,
      order_items: order_items
    }
  end

  def place(order) do
    payment_order_id = generate()

    payment_amount =
      Enum.reduce(order.order_items, 0, fn {_, item}, acc ->
        acc + item.unit_price * item.quantity
      end)

    payment_order = PaymentOrder.new(payment_amount, :pending)

    %{order | state: :placed, payment_orders: %{payment_order_id => payment_order}}
  end

  def pay(order) do
    updated_payment_orders =
      Enum.map(order.payment_orders, fn {id, payment_order} ->
        {id, %{payment_order | state: :paid}}
      end)
      |> Enum.into(%{})

    new_state =
      if order.delivery_state == :delivered do
        :completed
      else
        :paid
      end

    %{order | state: new_state, payment_state: :paid, payment_orders: updated_payment_orders}
  end

  def deliver(order) do
    updated_state =
      if order.payment_state == :paid do
        :completed
      else
        :delivered
      end

    %{order | state: updated_state, delivery_state: :delivered}
  end
end
