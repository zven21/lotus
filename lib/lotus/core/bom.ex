defmodule Lotus.Core.BOM do
  @moduledoc """
  # BOM 结构体，增加委外组件标识
  """
  alias Lotus.Core.BOMItem

  @enforce_keys [:id, :components]
  @type component :: %{
          component_id: binary(),
          quantity: integer(),
          outsourced: boolean()
        }
  @type t :: %__MODULE__{
          id: binary(),
          components: %{binary() => BOMItem.t()}
        }

  defstruct id: nil,
            components: %{}

  def new(id, components) do
    %__MODULE__{
      id: id,
      components: components
    }
  end
end
