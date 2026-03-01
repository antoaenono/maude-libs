defmodule MaudeLibsWeb.CanvasLive do
  use MaudeLibsWeb, :live_view

  alias MaudeLibs.CanvasServer

  @impl true
  def mount(_params, session, socket) do
    username = session["username"]

    if is_nil(username) do
      {:ok, push_navigate(socket, to: "/join")}
    else
      if connected?(socket) do
        Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "canvas")
        Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "user:#{username}")
      end

      circles = CanvasServer.get_state()
      {:ok, assign(socket, username: username, circles: circles, invite: nil)}
    end
  end

  @impl true
  def handle_info({:canvas_updated, circles}, socket) do
    {:noreply, assign(socket, circles: circles)}
  end

  def handle_info({:invited, id, topic}, socket) do
    {:noreply, assign(socket, invite: %{id: id, topic: topic})}
  end

  @impl true
  def handle_event("dismiss_invite", _params, socket) do
    {:noreply, assign(socket, invite: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-screen h-screen bg-base-200 overflow-hidden relative select-none">
      <%!-- Username badge --%>
      <div class="fixed top-4 left-4 z-10">
        <span class="badge badge-ghost font-mono">{@username}</span>
      </div>
       <%!-- Decision circles --%>
      <%= for {id, circle} <- @circles do %>
        <.circle id={id} circle={circle} />
      <% end %>
       <%!-- Plus button fixed at center --%>
      <a
        href="/d/new"
        class="fixed z-10 btn btn-circle btn-primary shadow-lg"
        style="left: 50%; top: 50%; transform: translate(-50%, -50%);"
        title="New Decision"
      >
        <span class="text-2xl leading-none">+</span>
      </a> <%!-- Invite modal --%>
      <%= if @invite do %>
        <div class="fixed inset-0 bg-black/40 z-20 flex items-center justify-center">
          <div class="bg-base-100 rounded-2xl shadow-2xl p-8 max-w-sm w-full mx-4 flex flex-col gap-4">
            <h3 class="text-lg font-bold">You've been invited</h3>
            
            <p class="text-base-content/70">
              Join the decision:
              <span class="font-semibold text-base-content">{@invite.topic || "New decision"}</span>
            </p>
            
            <div class="flex gap-3">
              <a href={"/d/#{@invite.id}"} class="btn btn-primary flex-1">Join</a>
              <button phx-click="dismiss_invite" class="btn btn-ghost flex-1">Later</button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp circle(assigns) do
    assigns = assign(assigns, :stage_color, stage_color(assigns.circle.stage))

    ~H"""
    <a
      href={"/d/#{@id}"}
      class={"absolute z-10 flex flex-col items-center justify-center rounded-full shadow-xl
              cursor-pointer transition-all duration-700 ease-in-out
              w-32 h-32 text-center #{@stage_color}
              hover:scale-110 hover:shadow-2xl"}
      style={"left: #{@circle.x}%; top: #{@circle.y}%; transform: translate(-50%, -50%);"}
    >
      <span class="font-bold text-xs px-2 leading-tight line-clamp-2">{@circle.title}</span>
      <%= if @circle.tagline do %>
        <span class="text-xs opacity-70 px-2 mt-1 leading-tight line-clamp-2">{@circle.tagline}</span>
      <% end %>
    </a>
    """
  end

  defp stage_color(:complete),
    do: "bg-success text-success-content border-2 border-success-content/20"

  defp stage_color(:lobby), do: "bg-base-100 text-base-content border-2 border-base-300"
  defp stage_color(_), do: "bg-primary text-primary-content border-2 border-primary-content/20"
end
