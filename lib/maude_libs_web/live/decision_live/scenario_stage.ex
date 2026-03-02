defmodule MaudeLibsWeb.DecisionLive.ScenarioStage do
  use Phoenix.Component
  import MaudeLibsWeb.DecisionLive.DecisionComponents
  import MaudeLibsWeb.DecisionLive.StageShell

  alias MaudeLibsWeb.StageLayout

  def scenario_stage(assigns) do
    s = assigns.decision.stage
    my_vote = Map.get(s.votes, assigns.username)

    other_users =
      MapSet.to_list(assigns.decision.connected) |> Enum.reject(&(&1 == assigns.username))

    stage_context = %{
      has_content: s.synthesis != nil,
      is_thinking: s.synthesizing,
      suggestion_count: if(s.synthesis, do: 1, else: 0)
    }

    positions = StageLayout.compute(other_users, stage_context)
    {claude_x, claude_y} = StageLayout.claude_pos()
    {your_x, your_y} = StageLayout.your_pos()
    {virtual_w, virtual_h} = StageLayout.virtual_size()

    assigns =
      assign(assigns,
        s: s,
        my_vote: my_vote,
        other_users: other_users,
        positions: positions,
        claude_x: claude_x,
        claude_y: claude_y,
        your_x: your_x,
        your_y: your_y,
        virtual_w: virtual_w,
        virtual_h: virtual_h
      )

    ~H"""
    <.stage_shell stage={@decision.stage}>
      <:header>
        <div class="bg-base-100/80 backdrop-blur border-b border-base-300 px-8 py-4 flex flex-col items-center gap-1">
          <span class="text-xs font-mono text-base-content/40 uppercase tracking-widest">
            Frame the scenario
          </span> <span class="text-lg font-semibold text-base-content">{@decision.topic}</span>
          <span class="text-xs text-base-content/40">
            Vote on a framing - everyone must agree to proceed
          </span>
        </div>
      </:header>

      <div id="scenario-canvas" phx-hook="ScaleToFit"
           class="w-full h-full flex items-center justify-center overflow-hidden">
        <div data-testid="virtual-canvas" class="relative select-none"
             style={"width: #{@virtual_w}px; height: #{@virtual_h}px; transform: scale(var(--canvas-scale, 1)); transform-origin: center center;"}>
          <%!-- Other participants' cards --%>
          <%= for user <- @other_users do %>
            <% {x, y} = Map.get(@positions, user, {500.0, 210.0}) %> <% text =
              Map.get(@s.submissions, user, "") %> <% voted = Map.get(@s.votes, user) %>
            <div
              class="absolute transition-all duration-700 ease-in-out"
              style={"left: #{x}px; top: #{y}px; transform: translate(-50%, -50%);"}
            >
              <.candidate_card
                text={if text != "", do: text, else: nil}
                label={user}
                voted={voted != nil}
                selected={@my_vote != nil and @my_vote == text and text != ""}
                is_synthesis={false}
                spectator={@spectator}
                placeholder="thinking..."
              />
            </div>
          <% end %>

          <%!-- Claude synthesis (always at center, invisible when empty) --%>
          <div
            class={"absolute transition-all duration-700 ease-in-out " <> if(@s.synthesis || @s.synthesizing, do: "opacity-100", else: "opacity-0 pointer-events-none")}
            style={"left: #{@claude_x}px; top: #{@claude_y}px; transform: translate(-50%, -50%);"}
          >
            <%= if @s.synthesis do %>
              <.candidate_card
                text={@s.synthesis}
                label="Claude"
                voted={false}
                selected={@my_vote == @s.synthesis}
                is_synthesis={true}
                spectator={@spectator}
                placeholder={nil}
                thinking={@s.synthesizing}
              />
            <% else %>
              <.claude_thinking label="Claude" />
            <% end %>
          </div>

          <%!-- Your card (bottom center) --%>
          <div
            class="absolute transition-all duration-700 ease-in-out"
            style={"left: #{@your_x}px; top: #{@your_y}px; transform: translate(-50%, -50%);"}
          >
            <% my_text = Map.get(@s.submissions, @username, "") %>
            <%= if @spectator do %>
              <.candidate_card
                text={if my_text != "", do: my_text, else: nil}
                label="you (spectating)"
                voted={@my_vote != nil}
                selected={false}
                is_synthesis={false}
                spectator={true}
                placeholder="spectating"
              />
            <% else %>
              <div class={"card w-96 border-2 bg-base-100 shadow-xl " <> if(@my_vote != nil, do: "border-primary", else: "border-base-300")}>
                <div class="card-body p-4 gap-3">
                   <% my_sub = Map.get(@s.submissions, @username) %>
                  <%= if my_sub && my_sub != "" do %>
                    <button
                      phx-click="vote_scenario"
                      phx-value-candidate={my_sub}
                      class={"btn btn-xs " <> if(@my_vote == my_sub, do: "btn-primary", else: "btn-outline btn-primary")}
                    >
                      {if @my_vote == my_sub, do: "Your vote ✓", else: "Vote for yourself"}
                    </button>
                  <% end %>

                  <form
                    id="scenario-input"
                    phx-update="ignore"
                    phx-submit="submit_scenario"
                    class="flex gap-2 mt-1"
                  >
                    <input
                      type="text"
                      name="text"
                      value={my_sub || ""}
                      placeholder={scenario_placeholder(@username)}
                      class="input input-bordered input-sm flex-1"
                      autocomplete="off"
                    /> <button type="submit" class="btn btn-sm btn-outline">Save</button>
                  </form>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Vote tally (bottom right) --%>
          <div class="absolute bottom-4 right-4 text-xs text-base-content/40 font-mono">
            {map_size(@s.votes)} / {MapSet.size(@decision.connected)} voted
          </div>
        </div>
      </div>
    </.stage_shell>
    """
  end

  defp scenario_placeholder(username) do
    Enum.random([
      "So what's the scenario?",
      "What's the scenario?",
      "What, so what's the scenario?",
      "So what, so what's the scenario?",
      "What, so what, so what's the scenario?",
      "So what, so what, so what's the scenario?",
      "#{username} with the scenario:",
      "So here's #{username} with the scenario:"
    ])
  end

  def scenario_modal(assigns) do
    ~H"""
    <.modal_overlay>
      <h3 class="text-lg font-bold">Frame the Scenario</h3>

      <p>
        Everyone votes on the framing of the decision. You must all agree on the same framing to proceed.
      </p>

      <ul class="list-disc list-inside text-sm text-base-content/70 gap-1 flex flex-col">
        <li>The creator's topic is pre-filled as the default candidate</li>

        <li>Anyone can optionally submit a rephrase</li>

        <li>If there are multiple submissions, Claude synthesizes a bridge candidate</li>

        <li>Click a card to vote. All votes must match to advance.</li>
      </ul>
    </.modal_overlay>
    """
  end
end
