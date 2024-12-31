defmodule Lotus.Core.Supplier do
  @moduledoc false

  @enforce_keys [:id, :name, :contact_info]

  @type t :: %__MODULE__{
          id: binary(),
          name: binary(),
          contact_info: binary()
        }

  defstruct id: nil,
            name: nil,
            contact_info: nil

  def new(id, name, contact_info) do
    %__MODULE__{
      id: id,
      name: name,
      contact_info: contact_info
    }
  end
end
