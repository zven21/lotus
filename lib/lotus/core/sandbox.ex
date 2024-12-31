defmodule Lotus.Core.Sandbox do
  def run() do
    # 创建供应商（假设）
    # supplier = Lotus.Core.Supplier.new("sup1", "Outsource Supplier", "contact@example.com")

    # # 创建原材料（木材和钉子）的BOM和Product
    # raw_material_bom_wood = Lotus.Core.BOM.new("raw_bom_wood", %{})
    # raw_material_bom_nail = Lotus.Core.BOM.new("raw_bom_nail", %{})
    # raw_material_process_flow_wood = Lotus.Core.ProcessFlow.new("raw_flow_wood", %{})
    # raw_material_process_flow_nail = Lotus.Core.ProcessFlow.new("raw_flow_nail", %{})

    # raw_material_wood = Lotus.Core.Product.new("raw_wood", "Wood", "Raw material for furniture", raw_material_bom_wood, raw_material_process_flow_wood, :raw_material)
    raw_material_nail =
      Lotus.Core.Product.new("raw_nail", "Nail", "Nail for furniture", nil, nil, :raw_material)

    # 创建半成品（桌面和桌腿）的BOM和Product
    desktop_component_product =
      Lotus.Core.Product.new(
        "semi_desktop",
        "Desktop",
        "Semi - finished desktop",
        nil,
        nil,
        :semi_finished_good
      )

    table_leg_component_product =
      Lotus.Core.Product.new(
        "semi_table_leg",
        "Table Leg",
        "Semi - finished table leg",
        nil,
        nil,
        :semi_finished_good
      )

    semi_finished_bom_desktop =
      Lotus.Core.BOM.new("semi_bom_desktop", %{
        "desktop_product_id" => Lotus.Core.BOMItem.new(desktop_component_product, 1, false)
      })

    semi_finished_bom_table_leg =
      Lotus.Core.BOM.new("semi_bom_table_leg", %{
        "table_leg_product_id" => Lotus.Core.BOMItem.new(table_leg_component_product, 1, false)
      })

    desktop_cutting_step = %{
      step_id: "desktop_cutting",
      name: "Cut Desktop",
      description: "Cut wood to desktop shape",
      operation: "Use cutting machine",
      outsourced: false
    }

    table_leg_cutting_step = %{
      step_id: "table_leg_cutting",
      name: "Cut Table Leg",
      description: "Cut wood to table leg shape",
      operation: "Use cutting machine",
      outsourced: false
    }

    semi_finished_process_flow_desktop =
      Lotus.Core.ProcessFlow.new("semi_flow_desktop", %{"desktop_cutting" => desktop_cutting_step})

    semi_finished_process_flow_table_leg =
      Lotus.Core.ProcessFlow.new("semi_flow_table_leg", %{
        "table_leg_cutting" => table_leg_cutting_step
      })

    semi_finished_desktop =
      Lotus.Core.Product.new(
        "semi_desktop",
        "Desktop",
        "Semi - finished desktop",
        semi_finished_bom_desktop,
        semi_finished_process_flow_desktop,
        :semi_finished_good
      )

    semi_finished_table_leg =
      Lotus.Core.Product.new(
        "semi_table_leg",
        "Table Leg",
        "Semi - finished table leg",
        semi_finished_bom_table_leg,
        semi_finished_process_flow_table_leg,
        :semi_finished_good
      )

    # 创建成品（桌子）的BOM和Product
    table_bom_components = %{
      "semi_desktop_id" => Lotus.Core.BOMItem.new(semi_finished_desktop, 1, false),
      "semi_table_leg_id" => Lotus.Core.BOMItem.new(semi_finished_table_leg, 4, false),
      "nail_id" => Lotus.Core.BOMItem.new(raw_material_nail, 20, false)
    }

    table_assembly_step = %{
      step_id: "table_assembly",
      name: "Assemble Table",
      description: "Assemble desktop and table legs with nails",
      operation: "Use tools",
      outsourced: false
    }

    table_quality_check_step = %{
      step_id: "table_quality_check",
      name: "Quality Check",
      description: "Check the quality of the assembled table",
      operation: "Use inspection tools",
      outsourced: false
    }

    table_packaging_step = %{
      step_id: "table_packaging",
      name: "Package Table",
      description: "Package the table for shipping",
      operation: "Use packaging materials",
      outsourced: false
    }

    table_process_flow =
      Lotus.Core.ProcessFlow.new("table_process_flow", %{
        "table_assembly" => table_assembly_step,
        "table_quality_check" => table_quality_check_step,
        "table_packaging" => table_packaging_step
      })

    table_bom = Lotus.Core.BOM.new("table_bom", table_bom_components)

    finished_table =
      Lotus.Core.Product.new(
        "finished_table",
        "Table",
        "Finished table",
        table_bom,
        table_process_flow,
        :finished_good
      )

    IO.inspect(finished_table)
  end
end
