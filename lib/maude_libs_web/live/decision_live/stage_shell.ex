defmodule MaudeLibsWeb.DecisionLive.StageShell do
  use Phoenix.Component
  import MaudeLibsWeb.DecisionLive.DecisionComponents, only: [breadcrumbs: 1]

  attr :stage, :any, required: true
  slot :header
  slot :inner_block, required: true
  slot :footer

  def stage_shell(assigns) do
    ~H"""
    <div class="h-dvh flex flex-col overflow-hidden bg-base-200" data-testid="stage-shell">
      <.breadcrumbs stage={@stage} />

      <%= if @header != [] do %>
        <div class="shrink-0" data-testid="stage-header">
          {render_slot(@header)}
        </div>
      <% end %>

      <div class="flex-1 min-h-0 relative">
        {render_slot(@inner_block)}
      </div>

      <%= if @footer != [] do %>
        <div class="shrink-0" data-testid="stage-footer">
          {render_slot(@footer)}
        </div>
      <% end %>
    </div>
    """
  end
end
