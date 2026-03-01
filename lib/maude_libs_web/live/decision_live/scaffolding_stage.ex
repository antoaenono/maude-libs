defmodule MaudeLibsWeb.DecisionLive.ScaffoldingStage do
  use Phoenix.Component

  def scaffolding_stage(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col items-center justify-center gap-6">
      <div class="loading loading-spinner loading-lg text-primary"></div>

      <p class="text-xl font-semibold text-base-content/70">Spelunking...</p>

      <p class="text-sm text-base-content/40">Claude is analyzing your options against priorities</p>
    </div>
    """
  end
end
