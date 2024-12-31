defmodule Lotus.Core.StockLocation do
  @moduledoc """
  Domain model for StockLocation
  """

  @enforce_keys [:id, :name]

  @type t :: %__MODULE__{
          id: binary(),
          name: binary()
        }

  defstruct [
    :id,
    :name
  ]

  @doc """
  Create a new StockLocation instance.
  """
  def new(id, name) do
    %__MODULE__{
      id: id,
      name: name
    }
  end
end
