defmodule Lotus.Core.Variant do
  @moduledoc """
  Domain model for Variant, similar to SKU
  """

  alias Lotus.Core.StockItem

  @enforce_keys [:id, :name, :selling_price]

  @type stock_item :: StockItem.t()

  @type t :: %__MODULE__{
          id: binary(),
          name: binary(),
          description: binary() | nil,
          selling_price: number(),
          stock_items: %{
            binary() => stock_item()
          }
        }

  defstruct [
    :id,
    :name,
    :description,
    :selling_price,
    stock_items: %{}
  ]

  @doc """
  Create a new Variant instance.

  ## Parameters
  - request: A map containing the fields for the variant. Must include `:id`, `:name`, and `:selling_price`.

  ## Returns
  - A new `Variant` struct if the request has the required fields.
  """
  def new(id, name, description, selling_price) do
    %__MODULE__{
      id: id,
      name: name,
      description: description,
      selling_price: selling_price
    }
  end

  @doc """
  Add stock to a specific stock location.

  ## Parameters
  - variant: The `Variant` struct.
  - stock_location: The `StockLocation` struct where the stock is added.
  - quantity: The number of items to add to the stock.

  ## Returns
  - A new `Variant` struct representing the added stock.
  """
  def add_stock(variant, stock_location, quantity) do
    stock_item = StockItem.new(variant, stock_location, quantity)

    updated_stock_items =
      variant.stock_items
      |> Map.put(stock_item.id, stock_item)

    %__MODULE__{
      variant
      | stock_items: updated_stock_items
    }
  end
end
