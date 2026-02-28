defmodule MaudeLibsWeb.CanvasLive do
  use MaudeLibsWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    username = session["username"]

    if is_nil(username) do
      {:ok, push_navigate(socket, to: "/join")}
    else
      {:ok, assign(socket, username: username, decisions: [], invite_prompt: nil)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 flex flex-col items-center justify-center gap-4">
      <p class="text-base-content/50 text-sm">Canvas - coming in Step 6</p>
      <p class="text-base-content">Logged in as <strong><%= @username %></strong></p>
      <a href="/d/new" class="btn btn-primary">+ New Decision</a>
    </div>
    """
  end
end
