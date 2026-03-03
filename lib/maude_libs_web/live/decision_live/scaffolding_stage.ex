defmodule MaudeLibsWeb.DecisionLive.ScaffoldingStage do
  use Phoenix.Component
  import MaudeLibsWeb.DecisionLive.StageShell

  def scaffolding_stage(assigns) do
    assigns = assign(assigns, :llm_error, assigns.decision.stage.llm_error)

    ~H"""
    <.stage_shell stage={@decision.stage}>
      <div class="h-full flex flex-col items-center justify-center gap-6">
        <%= if @llm_error do %>
          <div class="text-error text-4xl">!</div>
          <p class="text-xl font-semibold text-error/70">Analysis failed</p>
          <p class="text-sm text-base-content/40">The API request didn't go through</p>
          <button phx-click="retry_scaffold" class="btn btn-outline btn-primary btn-sm">
            Retry
          </button>
        <% else %>
          <div class="loading loading-spinner loading-lg text-primary"></div>
          <p class="text-xl font-semibold text-base-content/70">Spelunking...</p>
          <p class="text-sm text-base-content/40">
            Claude is analyzing your options against priorities
          </p>
        <% end %>
      </div>
    </.stage_shell>
    """
  end
end
