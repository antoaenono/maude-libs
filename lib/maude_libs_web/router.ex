defmodule MaudeLibsWeb.Router do
  use MaudeLibsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MaudeLibsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MaudeLibsWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/join", JoinLive
    post "/session", SessionController, :create
    live "/canvas", CanvasLive
    live "/d/:id", DecisionLive
  end

  if Mix.env() == :dev do
    scope "/dev", MaudeLibsWeb.Dev do
      pipe_through :browser
      get "/seed/:stage", SeedController, :create
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", MaudeLibsWeb do
  #   pipe_through :api
  # end
end
