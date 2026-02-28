defmodule MaudeLibsWeb.JoinLive do
  use MaudeLibsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, username: "")}
  end

  @impl true
  def handle_event("change", %{"username" => username}, socket) do
    {:noreply, assign(socket, username: username)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200">
      <div class="card w-96 bg-base-100 shadow-xl">
        <div class="card-body items-center text-center gap-6">
          <h1 class="card-title text-3xl font-bold">Maude Libs</h1>
          <p class="text-base-content/70">Group decisions, live.</p>

          <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
            <div class="alert alert-error w-full">
              <span><%= flash %></span>
            </div>
          <% end %>

          <form action="/session" method="post" phx-change="change" class="w-full flex flex-col gap-4">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <div class="form-control w-full">
              <label class="label">
                <span class="label-text">Choose a username</span>
                <span class="label-text-alt text-base-content/50">max 8 chars, letters & numbers</span>
              </label>
              <input
                type="text"
                name="username"
                value={@username}
                placeholder="alice"
                maxlength="8"
                autocomplete="off"
                autofocus
                class="input input-bordered w-full"
              />
            </div>

            <button type="submit" class="btn btn-primary w-full" disabled={@username == ""}>
              Join
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
