defmodule Lotus.Core.WorkReport do
  @moduledoc false

  @enforce_keys [:id, :reported_at, :quantity_produced, :worker_id]
  @type t :: %__MODULE__{
          id: binary(),
          reported_at: DateTime.t(),
          quantity_produced: integer(),
          worker_id: binary()
        }

  defstruct id: nil,
            reported_at: nil,
            quantity_produced: nil,
            worker_id: nil

  def new(id, reported_at, quantity_produced, worker_id) do
    %__MODULE__{
      id: id,
      reported_at: reported_at,
      quantity_produced: quantity_produced,
      worker_id: worker_id
    }
  end
end
