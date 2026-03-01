defmodule MaudeLibsWeb.DecisionLive.DecisionComponents do
  use Phoenix.Component

  def modal_overlay(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black/40 z-20 flex items-center justify-center"
      phx-window-keydown="close_modal"
      phx-key="Escape"
    >
      <div
        class="bg-base-100 rounded-2xl shadow-2xl p-8 max-w-md w-full mx-4 flex flex-col gap-4"
        phx-click-away="close_modal"
      >
        <div class="flex justify-between items-start">
          <div class="flex flex-col gap-4">{render_slot(@inner_block)}</div>
           <button phx-click="close_modal" class="btn btn-sm btn-circle btn-ghost ml-4">✕</button>
        </div>

        <p class="text-xs text-base-content/40 text-right">Press Escape or click outside to close</p>
      </div>
    </div>
    """
  end

  def claude_thinking(assigns) do
    ~H"""
    <div class="card w-52 border-2 border-dashed border-secondary bg-base-100 shadow-md">
      <div class="card-body p-4 gap-2 items-center">
        <span class="badge badge-secondary badge-sm">{@label}</span>
        <div class="flex gap-1 items-center py-1">
          <span
            class="w-2 h-2 rounded-full bg-secondary opacity-60 animate-bounce"
            style="animation-delay: 0ms"
          >
          </span>
          <span
            class="w-2 h-2 rounded-full bg-secondary opacity-60 animate-bounce"
            style="animation-delay: 150ms"
          >
          </span>
          <span
            class="w-2 h-2 rounded-full bg-secondary opacity-60 animate-bounce"
            style="animation-delay: 300ms"
          >
          </span>
        </div>
      </div>
    </div>
    """
  end

  def mini_dots(assigns) do
    ~H"""
    <span class="flex gap-0.5 items-center">
      <span
        class="w-1 h-1 rounded-full bg-secondary opacity-70 animate-bounce"
        style="animation-delay: 0ms"
      >
      </span>
      <span
        class="w-1 h-1 rounded-full bg-secondary opacity-70 animate-bounce"
        style="animation-delay: 150ms"
      >
      </span>
      <span
        class="w-1 h-1 rounded-full bg-secondary opacity-70 animate-bounce"
        style="animation-delay: 300ms"
      >
      </span>
    </span>
    """
  end

  def candidate_card(assigns) do
    assigns =
      assigns
      |> assign_new(:placeholder, fn -> nil end)
      |> assign_new(:thinking, fn -> false end)

    ~H"""
    <div class={"card w-60 border-2 bg-base-100 shadow-md transition-all " <>
                 if(@selected, do: "border-primary bg-primary/10", else:
                   if(@is_synthesis, do: "border-dashed border-secondary", else: "border-base-300")) <>
                 if(@spectator or is_nil(@text), do: " cursor-default", else: " cursor-pointer hover:border-primary/60 hover:shadow-lg")}>
      <div class="card-body p-4 gap-2">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-1.5">
            <span class={"badge badge-sm " <> if(@is_synthesis, do: "badge-secondary", else: "badge-ghost")}>
              {@label}
            </span>
            <%= if @thinking do %>
              <.mini_dots />
            <% end %>
          </div>

          <%= if @voted do %>
            <span class="text-xs text-base-content/40">voted ✓</span>
          <% end %>
        </div>

        <%= if @text do %>
          <p class="text-sm">{@text}</p>

          <%= if not @spectator and @text do %>
            <button
              phx-click="vote_scenario"
              phx-value-candidate={@text}
              class={"btn btn-xs mt-1 " <> if(@selected, do: "btn-primary", else: "btn-outline btn-primary")}
            >
              {if @selected, do: "Your vote ✓", else: "Vote"}
            </button>
          <% end %>
        <% else %>
          <p class="text-xs text-base-content/30 italic">{@placeholder || "..."}</p>
        <% end %>
      </div>
    </div>
    """
  end

  @stages [
    {:lobby, "Lobby"},
    {:scenario, "Scenario"},
    {:priorities, "Priorities"},
    {:options, "Options"},
    {:dashboard, "Dashboard"},
    {:complete, "Complete"}
  ]

  def breadcrumbs(assigns) do
    current = stage_key(assigns.stage)
    stage_order = Enum.map(@stages, fn {key, _} -> key end)
    current_idx = Enum.find_index(stage_order, &(&1 == current))

    steps =
      Enum.with_index(@stages)
      |> Enum.map(fn {{key, label}, idx} ->
        status =
          cond do
            idx < current_idx -> :done
            idx == current_idx -> :current
            true -> :upcoming
          end

        %{key: key, label: label, status: status}
      end)

    assigns = assign(assigns, steps: steps)

    ~H"""
    <nav class="w-full bg-base-100/60 backdrop-blur border-b border-base-300/50 px-4 py-2" data-testid="breadcrumbs" aria-label="Decision progress">
      <ol class="flex items-center justify-center gap-1 text-xs font-mono">
        <%= for {step, idx} <- Enum.with_index(@steps) do %>
          <%= if idx > 0 do %>
            <li class="text-base-content/20 select-none" aria-hidden="true">›</li>
          <% end %>
          <li class={breadcrumb_class(step.status)} data-stage={step.key} aria-current={if(step.status == :current, do: "step")}>
            <%= if step.status == :done do %>
              <span class="text-success">✓</span>
            <% end %>
            {step.label}
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end

  defp breadcrumb_class(:done), do: "text-success/70"
  defp breadcrumb_class(:current), do: "text-base-content font-semibold"
  defp breadcrumb_class(:upcoming), do: "text-base-content/30"

  defp stage_key(%MaudeLibs.Decision.Stage.Lobby{}), do: :lobby
  defp stage_key(%MaudeLibs.Decision.Stage.Scenario{}), do: :scenario
  defp stage_key(%MaudeLibs.Decision.Stage.Priorities{}), do: :priorities
  defp stage_key(%MaudeLibs.Decision.Stage.Options{}), do: :options
  defp stage_key(%MaudeLibs.Decision.Stage.Scaffolding{}), do: :dashboard
  defp stage_key(%MaudeLibs.Decision.Stage.Dashboard{}), do: :dashboard
  defp stage_key(%MaudeLibs.Decision.Stage.Complete{}), do: :complete

  def priority_badge_class("+"), do: "text-success border-success"
  def priority_badge_class("-"), do: "text-error border-error"
  def priority_badge_class(_), do: "text-base-content/50"
end
