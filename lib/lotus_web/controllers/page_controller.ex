defmodule LotusWeb.PageController do
  use LotusWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
