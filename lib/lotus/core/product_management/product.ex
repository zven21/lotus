defmodule Lotus.Core.Product do
  @moduledoc """
  Domain model for Product

    - The `Product` struct represents a product in the system.
    - It includes an identifier (`id`), name, description, its Bill of Materials (`bom`),
    - process flow (`process_flow`), and product type (`product_type`).
    - `product_type` can be :raw_material, :semi_finished_good, or :finished_good.

  """

  alias Lotus.Core.{BOM, ProcessFlow}

  @enforce_keys [:id, :name, :description, :bom, :process_flow, :product_type]
  @type product_type :: :raw_material | :semi_finished_good | :finished_good
  @type t :: %__MODULE__{
          id: binary(),
          name: binary(),
          description: binary(),
          bom: BOM.t(),
          process_flow: ProcessFlow.t(),
          product_type: product_type()
        }

  defstruct id: nil,
            name: nil,
            description: nil,
            bom: nil,
            process_flow: nil,
            product_type: nil

  @doc """
  Create a new Product instance.

  - `bom` is the Bill of Materials associated with the product.
  - `process_flow` represents the manufacturing process of the product.
  - `product_type` indicates whether it is a raw material, semi - finished good, or finished good.
  """
  def new(id, name, description, bom, process_flow, product_type) do
    %__MODULE__{
      id: id,
      name: name,
      description: description,
      bom: bom,
      process_flow: process_flow,
      product_type: product_type
    }
  end
end
