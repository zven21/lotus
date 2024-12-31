defmodule Lotus.Core.PaymentOrder do
  @moduledoc """
  Domain model for PaymentOrder
  """

  @enforce_keys [:id, :amount, :state]

  @type t :: %__MODULE__{
          id: binary(),
          amount: number(),
          state: atom()
        }

  defstruct id: nil,
            amount: nil,
            state: nil

  @doc """
  Create a new PaymentOrder instance.
  """
  def new(amount, payment_state) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      amount: amount,
      state: payment_state
    }
  end
end
