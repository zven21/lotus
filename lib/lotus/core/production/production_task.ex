defmodule Lotus.Core.ProductionTask do
  @moduledoc false

  alias Lotus.Core.{Resource, WorkReport}

  @enforce_keys [:id, :description, :resources, :progress, :work_reports, :state]
  @type t :: %__MODULE__{
          id: binary(),
          description: binary(),
          resources: %{binary() => Resource.t()},
          progress: integer(),
          work_reports: [WorkReport.t()],
          state: atom()
        }

  defstruct id: nil,
            description: nil,
            resources: %{},
            progress: 0,
            work_reports: [],
            state: :pending

  def new(id, description) do
    %__MODULE__{
      id: id,
      description: description,
      resources: %{},
      progress: 0,
      work_reports: [],
      state: :pending
    }
  end
end
