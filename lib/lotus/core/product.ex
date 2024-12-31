defmodule Lotus.Core.Product do
  @moduledoc """
  领域模型： 产品
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
