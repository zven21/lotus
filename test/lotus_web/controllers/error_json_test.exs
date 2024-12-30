defmodule LotusWeb.ErrorJSONTest do
  use LotusWeb.ConnCase, async: true

  test "renders 404" do
    assert LotusWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert LotusWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
