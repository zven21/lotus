defmodule Lotus.Core.ProductionPlan do
  @moduledoc """
  Domain model for Production Plan
  """

  alias Lotus.Core.{Product, ProductionTask, Resource, SubcontractingOrder}

  @enforce_keys [:id, :product, :start_date, :end_date, :tasks]
  @type t :: %__MODULE__{
          id: binary(),
          product: Product.t(),
          start_date: DateTime.t(),
          end_date: DateTime.t(),
          tasks: %{binary() => ProductionTask.t()},
          subcontracting_orders: %{binary() => SubcontractingOrder.t()}
        }

  defstruct id: nil,
            product: nil,
            start_date: nil,
            end_date: nil,
            tasks: %{},
            subcontracting_orders: %{}

  # Creates a production plan, automatically introducing BOM and ProcessFlow information to create tasks.
  def new(id, product, start_date, end_date) do
    bom = product.bom
    process_flow = product.process_flow

    tasks =
      Enum.reduce(process_flow.steps, %{}, fn {step_id, step}, acc ->
        task = %ProductionTask{
          id: step_id,
          description: step.description,
          resources: %{},
          work_reports: [],
          progress: 0,
          state: :pending
        }

        # Allocate resources to the task according to the BOM
        resources =
          Enum.map(bom.components, fn {_, component} ->
            resource = %Resource{
              id: component.component_id,
              name: "Component #{component.component_id}",
              quantity: component.quantity,
              available_quantity: component.quantity
            }
            {resource.id, resource}
          end)
          |> Enum.into(%{})

        updated_task = %{task | resources: resources}

        Map.put(acc, step_id, updated_task)
      end)

    subcontracting_orders = generate_subcontracting_orders(product, process_flow, start_date)

    %__MODULE__{
      id: id,
      product: product,
      start_date: start_date,
      end_date: end_date,
      tasks: tasks,
      subcontracting_orders: subcontracting_orders
    }
  end

  # Adds a production task to the plan.
  def add_task(plan, task_id, task) do
    %{plan | tasks: Map.put(plan.tasks, task_id, task)}
  end

  # Assigns a resource to a production task.
  def assign_resource(task, resource_id, resource) do
    updated_resources = Map.put(task.resources, resource_id, resource)
    %{task | resources: updated_resources}
  end

  # Updates the progress of a production task.
  def update_task_progress(task, progress) do
    %{task | progress: progress}
  end

  # Records the work report information of a production task and updates its state.
  def report_work(task_id, plan, report) do
    task = plan.tasks[task_id]
    updated_work_reports = [report | task.work_reports]
    new_state = calculate_task_state(updated_work_reports, task)
    updated_task = %{task | work_reports: updated_work_reports, state: new_state}
    %{plan | tasks: Map.put(plan.tasks, task_id, updated_task)}
  end

  # Calculates the task state based on the work report.
  defp calculate_task_state(work_reports, task) do
    total_quantity = Enum.reduce(task.resources, 0, fn {_, resource}, acc -> acc + resource.quantity end)
    reported_quantity = Enum.reduce(work_reports, 0, fn report, acc -> acc + report.quantity_produced end)

    cond do
      reported_quantity >= total_quantity -> :completed
      reported_quantity > 0 -> :in_progress
      true -> :pending
    end
  end

  # Generates subcontracting orders.
  # FIXME The subcontracting orders here are still under consideration.
  defp generate_subcontracting_orders(product, process_flow, start_date) do
    process_flow.steps
    |> Enum.filter(fn {_, step} -> step.outsourced end)
    |> Enum.map(fn {step_id, step} ->
      supplier = step.supplier
      bom_components = Enum.filter(product.bom.components, fn {_, component} -> component.outsourced end)
      relevant_steps = %{step_id => step}

      due_date = Timex.shift(start_date, days: 3)

      {
        step_id,
        SubcontractingOrder.new(
          step_id,
          product,
          supplier,
          bom_components,
          relevant_steps,
          due_date
        )
      }
    end)
    |> Enum.into(%{})
  end
end
