defmodule Lotus.Core.ProductionPlanTest do
  @moduledoc false

  use ExUnit.Case

  import Ecto.UUID
  alias Lotus.Core.{ProductionPlan, WorkReport, BOM, ProcessFlow, Product}

  setup do
    # 创建 BOM
    component1 = %{component_id: generate(), quantity: 2}
    component2 = %{component_id: generate(), quantity: 3}
    components = %{component1.component_id => component1, component2.component_id => component2}
    bom = BOM.new(generate(), components)

    # 创建工艺流程
    step1 = %{step_id: generate(), name: "Cutting", description: "Cut the material", operation: "Use cutting machine", outsourced: false}
    step2 = %{step_id: generate(), name: "Welding", description: "Weld the parts", operation: "Use welding equipment", outsourced: false}
    steps = %{step1.step_id => step1, step2.step_id => step2}
    process_flow = ProcessFlow.new(generate(), steps)

    # 创建产品
    product = Product.new(generate(), "Test Product", "A test product", bom, process_flow)

    # 创建生产计划
    start_date = Timex.now()
    end_date = Timex.shift(start_date, days: 5)
    plan = ProductionPlan.new(generate(), product, start_date, end_date)

    %{plan: plan, step1_id: step1.step_id, step2_id: step2.step_id}
  end

  test "report_work updates task state to in_progress", %{plan: plan, step1_id: step1_id} do
    report = WorkReport.new(generate(), Timex.now(), 1, generate())
    new_plan = ProductionPlan.report_work(step1_id, plan, report)
    task = new_plan.tasks[step1_id]
    assert task.state == :in_progress
  end

  test "report_work updates task state to completed", %{plan: plan, step1_id: step1_id} do
    component1 = plan.product.bom.components[Enum.at(Map.keys(plan.product.bom.components), 0)]
    component2 = plan.product.bom.components[Enum.at(Map.keys(plan.product.bom.components), 1)]

    report1 = WorkReport.new(generate(), Timex.now(), component1.quantity, generate())
    report2 = WorkReport.new(generate(), Timex.now(), component2.quantity, generate())

    new_plan = ProductionPlan.report_work(step1_id, plan, report1)
    new_plan = ProductionPlan.report_work(step1_id, new_plan, report2)

    task = new_plan.tasks[step1_id]
    assert task.state == :completed
  end

  test "production_plan_creation", %{plan: plan} do
    assert map_size(plan.tasks) == 2

    Enum.each(plan.tasks, fn {_, task} ->
      assert task.description != nil
      assert map_size(task.resources) == 2
    end)
  end
end
