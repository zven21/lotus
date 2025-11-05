defmodule LotusWeb.Router do
  use LotusWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LotusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json", "json-api"]
  end

  scope "/", LotusWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/cms", CMSLive.Index, :index
    live "/cms/builder", CMSLive.BuilderIndex, :index
    live "/cms/types/:id", CMSLive.TypeShow, :show
    live "/cms/:slug/entries", CMSLive.EntriesIndex, :index

    # Controller 版本作为后备（如果需要，可保留不同路径）
    # get "/cms/:slug/entries", CMS.EntryController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api/json" do
    pipe_through :api
    forward "/", AshJsonApi.Controllers.Router, domains: [Lotus.CMS.AshDomain]
  end

  # GraphQL 路由必须在 JSON:API 之前，避免被 catch-all forward 拦截
  scope "/api" do
    pipe_through :api
    forward "/graphql", Absinthe.Plug, schema: LotusWeb.Schema

    if Application.compile_env(:lotus, :dev_routes) do
      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: LotusWeb.Schema,
        json_codec: Jason,
        interface: :playground
    end
  end

  # Generated 域的 JSON:API（从配置文件生成）
  # 注意：这个 forward "/" 会匹配所有 /api/* 路径，所以必须放在 GraphQL 之后
  scope "/api" do
    pipe_through :api
    forward "/", AshJsonApi.Controllers.Router, domains: [Lotus.CMS.Generated]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:lotus, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LotusWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
