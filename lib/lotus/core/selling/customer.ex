defmodule Lotus.Core.Customer do
  @moduledoc """
  Domain model for Customer
  """

  @type t :: %__MODULE__{
          id: binary(),
          name: binary(),
          address: binary()
        }

  defstruct [
    :id,
    :name,
    :address
  ]

  def new(id, name, address) do
    %__MODULE__{
      id: id,
      name: name,
      address: address
    }
  end
end
