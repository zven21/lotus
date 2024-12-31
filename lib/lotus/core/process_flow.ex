defmodule Lotus.Core.ProcessFlow do
  @moduledoc """
  # 工艺流程结构体，增加委外工序标识
  """
  @enforce_keys [:id, :steps]
  @type step :: %{
          step_id: binary(),
          name: binary(),
          description: binary(),
          operation: binary(),
          outsourced: boolean(),
          supplier: Supplier.t() | nil
        }
  @type t :: %__MODULE__{
          id: binary(),
          steps: %{binary() => step()}
        }

  defstruct id: nil,
            steps: %{}

  def new(id, steps) do
    %__MODULE__{
      id: id,
      steps: steps
    }
  end
end
