defmodule Lotus.Core.ProductTest do
  @moduledoc false

  use ExUnit.Case

  alias Lotus.Core.{BOM, BOMItem, ProcessFlow, Product}
  import Ecto.UUID

  setup do
    # Create raw materials (wood)
    raw_material_bom_wood = BOM.new(generate(), %{})
    raw_material_process_flow_wood = ProcessFlow.new(generate(), %{})
    raw_material_wood = Product.new(generate(), "Wood", "Raw material for furniture", raw_material_bom_wood, raw_material_process_flow_wood, :raw_material)

    # Create semi-finished product (desktop)
    desktop_bom_item = BOMItem.new(raw_material_wood, 1, false)
    desktop_bom = BOM.new(generate(), %{"wood_component_id" => desktop_bom_item})
    desktop_process_flow = ProcessFlow.new(generate(), %{})
    semi_finished_desktop = Product.new(generate(), "Desktop", "Semi - finished desktop", desktop_bom, desktop_process_flow, :semi_finished_good)

    # Create finished product (table)
    table_bom_item = BOMItem.new(semi_finished_desktop, 1, false)
    table_bom = BOM.new(generate(), %{"desktop_component_id" => table_bom_item})
    table_process_flow = ProcessFlow.new(generate(), %{})
    finished_table = Product.new(generate(), "Table", "Finished table", table_bom, table_process_flow, :finished_good)

    %{
      finished_table: finished_table,
      semi_finished_desktop: semi_finished_desktop,
      raw_material_wood: raw_material_wood
    }
  end

  test "product_bom_association", %{finished_table: finished_table, semi_finished_desktop: semi_finished_desktop, raw_material_wood: raw_material_wood} do
    # Check if the BOM of the finished table is associated with the correct semi-finished desktop
    assert Map.has_key?(finished_table.bom.components, "desktop_component_id")
    bom_item = finished_table.bom.components["desktop_component_id"]
    assert bom_item.product == semi_finished_desktop

    # Check if the BOM of the semi-finished desktop is associated with the correct raw material wood
    assert Map.has_key?(semi_finished_desktop.bom.components, "wood_component_id")
    sub_bom_item = semi_finished_desktop.bom.components["wood_component_id"]
    assert sub_bom_item.product == raw_material_wood
  end

  test "bom_item_quantity_and_outsourced", %{finished_table: finished_table} do
    # Check the quantity and outsourcing attributes of desktop components in the finished table BOM
    bom_item = finished_table.bom.components["desktop_component_id"]
    assert bom_item.quantity == 1
    assert bom_item.outsourced == false
  end
end
