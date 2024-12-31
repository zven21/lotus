defmodule Lotus.Core.Resource do
  @moduledoc false

  @enforce_keys [:id, :name, :quantity, :available_quantity]

  @type t :: %__MODULE__{
          id: binary(),
          name: binary(),
          quantity: integer(),
          available_quantity: integer()
        }

  defstruct id: nil,
            name: nil,
            quantity: nil,
            available_quantity: nil

  def new(id, name, quantity) do
    %__MODULE__{
      id: id,
      name: name,
      quantity: quantity,
      available_quantity: quantity
    }
  end
end
