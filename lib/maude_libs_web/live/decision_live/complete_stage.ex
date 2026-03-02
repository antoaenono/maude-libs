defmodule MaudeLibsWeb.DecisionLive.CompleteStage do
  use Phoenix.Component
  import MaudeLibsWeb.DecisionLive.DecisionComponents, only: [priority_badge_class: 1, modal_overlay: 1]
  import MaudeLibsWeb.DecisionLive.StageShell

  def complete_stage(assigns) do
    s = assigns.decision.stage
    priority_names = Map.new(assigns.decision.priorities, &{&1.id, &1.text})

    assigns =
      assign(assigns,
        s: s,
        priorities: assigns.decision.priorities,
        priority_names: priority_names
      )

    ~H"""
    <.stage_shell stage={@decision.stage}>
      <div class="h-full overflow-y-auto p-8">
        <div class="max-w-3xl mx-auto flex flex-col gap-8">
          <%!-- Why statement --%>
          <div class="card bg-primary/10 border-2 border-primary/30">
            <div class="card-body gap-3">
              <div class="flex items-center gap-2">
                <span class="badge badge-primary">Decision</span>
                <h2 class="font-bold text-lg">{@s.winner}</h2>
              </div>

              <%= if @s.why_statement do %>
                <p class="text-base-content/80 leading-relaxed">{@s.why_statement}</p>
              <% else %>
                <div class="flex items-center gap-2 text-base-content/40">
                  <span class="loading loading-dots loading-sm"></span>
                  <span class="text-sm">Generating summary...</span>
                </div>
              <% end %>
            </div>
          </div>

          <%!-- Scenario --%>
          <div>
            <p class="text-xs text-base-content/40 uppercase tracking-wide mb-1">Scenario</p>

            <p class="font-semibold">{@decision.topic}</p>
          </div>

          <%!-- Priorities --%>
          <%= if length(@priorities) > 0 do %>
            <div>
              <p class="text-xs text-base-content/40 uppercase tracking-wide mb-2">Priorities</p>

              <div class="flex flex-wrap gap-2">
                <%= for p <- @priorities do %>
                  <span class={"badge badge-outline font-mono " <> priority_badge_class(p.direction)}>
                    {p.direction} {p.text}
                  </span>
                <% end %>
              </div>
            </div>
          <% end %>

          <%!-- Options sorted by vote count --%>
          <div class="flex flex-col gap-4">
            <p class="text-xs text-base-content/40 uppercase tracking-wide">Options</p>

            <%= for {opt, idx} <- Enum.with_index(@s.options) do %>
              <div class={"card border-2 " <> if(idx == 0, do: "border-primary bg-primary/5", else: "border-base-300 bg-base-100")}>
                <div class="card-body p-4 gap-3">
                  <div class="flex items-center gap-2">
                    <%= if idx == 0 do %>
                      <span class="badge badge-primary badge-sm">Winner</span>
                    <% end %>

                    <h3 class="font-bold">{opt.name}</h3>
                     <span class="text-xs text-base-content/50 ml-auto">{opt.desc}</span>
                  </div>

                  <div class="grid grid-cols-2 gap-3">
                    <div class="flex flex-col gap-1">
                      <p class="text-xs font-semibold text-success">For</p>

                      <%= for point <- opt.for do %>
                        <div class="flex gap-1 items-start">
                          <span class="badge badge-xs badge-outline text-success border-success flex-shrink-0 mt-0.5">
                            {Map.get(@priority_names, point.priority_id, point.priority_id)}
                          </span>
                          <p class="text-xs text-base-content/70">{point.text}</p>
                        </div>
                      <% end %>
                    </div>

                    <div class="flex flex-col gap-1">
                      <p class="text-xs font-semibold text-error">Against</p>

                      <%= for point <- opt.against do %>
                        <div class="flex gap-1 items-start">
                          <span class="badge badge-xs badge-outline text-error border-error flex-shrink-0 mt-0.5">
                            {Map.get(@priority_names, point.priority_id, point.priority_id)}
                          </span>
                          <p class="text-xs text-base-content/70">{point.text}</p>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <div class="text-center"><a href="/canvas" class="btn btn-ghost btn-sm">Back to canvas</a></div>
        </div>
      </div>
    </.stage_shell>
    """
  end

  def complete_modal(assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Decision Record</h3>

      <p>The decision is complete. This is the full record - shareable and self-documenting.</p>

      <p class="text-sm text-base-content/60">
        The why-statement at the top summarises the winner and the reasoning.
      </p>
    </.modal_overlay>
    """
  end
end
