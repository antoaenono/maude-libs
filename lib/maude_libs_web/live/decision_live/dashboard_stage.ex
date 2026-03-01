defmodule MaudeLibsWeb.DecisionLive.DashboardStage do
  use Phoenix.Component
  import MaudeLibsWeb.DecisionLive.DecisionComponents, only: [priority_badge_class: 1, modal_overlay: 1]

  alias MaudeLibs.Decision.Stage

  def dashboard_stage(assigns) do
    s = assigns.decision.stage
    my_votes = Map.get(s.votes, assigns.username, [])
    is_ready = assigns.username in s.ready
    vote_counts = count_votes_ui(s)
    sorted_by_votes = Enum.sort_by(s.options, &(-Map.get(vote_counts, &1.name, 0)))
    participants = MapSet.to_list(assigns.decision.connected)

    priority_names = Map.new(assigns.decision.priorities, &{&1.id, &1.text})

    assigns =
      assign(assigns,
        s: s,
        my_votes: my_votes,
        is_ready: is_ready,
        vote_counts: vote_counts,
        sorted_by_votes: sorted_by_votes,
        participants: participants,
        priorities: assigns.decision.priorities,
        priority_names: priority_names
      )

    ~H"""
    <div class="min-h-screen flex flex-col p-6 gap-6 max-w-6xl mx-auto">
      <%!-- Scenario + priorities header --%>
      <div class="flex flex-col gap-2">
        <p class="text-xs text-base-content/40 uppercase tracking-wide">Scenario</p>

        <p class="text-lg font-semibold">{@decision.topic}</p>
      </div>

      <%= if length(@priorities) > 0 do %>
        <div class="flex flex-wrap gap-2">
          <%= for p <- @priorities do %>
            <span class={"badge badge-outline font-mono " <> priority_badge_class(p.direction)}>
              {p.direction} {p.text}
            </span>
          <% end %>
        </div>
      <% end %>

      <div class="divider my-0"></div>
       <%!-- Main content: ranking sidebar + options cards --%>
      <div class="flex gap-6">
        <%!-- Left sidebar: live ranking --%>
        <div class="w-40 flex-shrink-0 flex flex-col gap-2">
          <p class="text-xs text-base-content/40 uppercase tracking-wide">Ranking</p>

          <%= for {opt, rank} <- Enum.with_index(@sorted_by_votes, 1) do %>
            <div class="flex items-center gap-2">
              <span class="text-xs text-base-content/40 w-4">{rank}.</span>
              <span class="text-xs font-mono truncate flex-1">{opt.name}</span>
              <span class="badge badge-sm">{Map.get(@vote_counts, opt.name, 0)}</span>
            </div>
          <% end %>
        </div>
         <%!-- Option cards --%>
        <div class="flex gap-4 overflow-x-auto pb-2 flex-1">
          <%= for opt <- @s.options do %>
            <% votes_for = Map.get(@vote_counts, opt.name, 0) %>
            <div
              phx-click={if not @spectator, do: "toggle_vote"}
              phx-value-option={opt.name}
              class={"card w-72 flex-shrink-0 border-2 transition-all " <>
                        if(opt.name in @my_votes, do: "border-primary bg-primary/5", else: "border-base-300 bg-base-100") <>
                        if(not @spectator, do: " cursor-pointer hover:border-primary/50", else: "")}
            >
              <div class="card-body p-4 gap-3">
                <%!-- Header --%>
                <div class="flex items-start justify-between gap-2">
                  <div>
                    <h3 class="font-bold text-sm">{opt.name}</h3>

                    <p class="text-xs text-base-content/60">{opt.desc}</p>
                  </div>
                   <span class="badge badge-sm flex-shrink-0">{votes_for} votes</span>
                </div>
                 <%!-- For points --%>
                <%= if length(opt.for) > 0 do %>
                  <div class="flex flex-col gap-1">
                    <p class="text-xs font-semibold text-success">For</p>

                    <table class="w-full text-xs">
                      <%= for point <- opt.for do %>
                        <tr>
                          <td class="w-px whitespace-nowrap pr-1.5 align-top pt-0.5">
                            <span class="badge badge-xs badge-outline text-success border-success">
                              {Map.get(@priority_names, point.priority_id, point.priority_id)}
                            </span>
                          </td>

                          <td class="text-base-content/70">{point.text}</td>
                        </tr>
                      <% end %>
                    </table>
                  </div>
                <% end %>
                 <%!-- Against points --%>
                <%= if length(opt.against) > 0 do %>
                  <div class="flex flex-col gap-1">
                    <p class="text-xs font-semibold text-error">Against</p>

                    <table class="w-full text-xs">
                      <%= for point <- opt.against do %>
                        <tr>
                          <td class="w-px whitespace-nowrap pr-1.5 align-top pt-0.5">
                            <span class="badge badge-xs badge-outline text-error border-error">
                              {Map.get(@priority_names, point.priority_id, point.priority_id)}
                            </span>
                          </td>

                          <td class="text-base-content/70">{point.text}</td>
                        </tr>
                      <% end %>
                    </table>
                  </div>
                <% end %>
                 <%!-- Participant vote checkboxes --%>
                <div class="flex flex-wrap gap-1 mt-auto pt-2 border-t border-base-200">
                  <%= for user <- @participants do %>
                    <% user_voted = opt.name in Map.get(@s.votes, user, []) %>
                    <button
                      phx-click={if user == @username, do: "toggle_vote", else: nil}
                      phx-value-option={opt.name}
                      class={"flex items-center gap-1 px-2 py-1 rounded text-xs font-mono transition-all " <>
                             if(user_voted, do: "bg-primary/20 text-primary", else: "bg-base-200 text-base-content/40") <>
                             if(user == @username, do: " cursor-pointer hover:bg-primary/30", else: " cursor-default")}
                    >
                      <%= if user_voted do %>
                        <span>✓</span>
                      <% end %>
                       {user}
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
       <%!-- Ready button --%>
      <%= if not @spectator do %>
        <div class="flex justify-end">
          <button
            phx-click="ready_dashboard"
            disabled={@my_votes == [] or @is_ready}
            class={"btn btn-primary " <> if(@is_ready, do: "btn-disabled", else: "")}
          >
            {if @is_ready, do: "Ready ✓", else: "Ready up"}
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  def dashboard_modal(assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Vote</h3>

      <p>Read each option's for/against analysis, then check every option you'd be happy with.</p>

      <ul class="list-disc list-inside text-sm text-base-content/70 gap-1 flex flex-col">
        <li>Approval voting - select as many as you'd accept</li>

        <li>You must select at least one to ready up</li>

        <li>Other participants' votes appear live on each card</li>

        <li>Ranking on the left updates as people vote</li>
      </ul>
    </.modal_overlay>
    """
  end

  defp count_votes_ui(%Stage.Dashboard{votes: votes, options: options}) do
    base = Map.new(options, &{&1.name, 0})

    Enum.reduce(votes, base, fn {_user, selected}, acc ->
      Enum.reduce(selected, acc, fn name, acc2 ->
        Map.update(acc2, name, 1, &(&1 + 1))
      end)
    end)
  end
end
