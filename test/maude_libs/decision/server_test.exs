defmodule MaudeLibs.Decision.ServerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias MaudeLibs.Decision.Server
  alias MaudeLibs.Decision.Supervisor, as: DecisionSup
  alias MaudeLibs.Decision.Stage

  # Each test gets a unique decision ID to avoid registry conflicts
  setup do
    id = "test-#{:erlang.unique_integer([:positive])}"
    {:ok, id: id}
  end

  defp start(id, creator \\ "alice", topic \\ "dinner?") do
    {:ok, _pid} = DecisionSup.start_decision(id, creator, topic)
    id
  end

  defp msg(id, message), do: Server.handle_message(id, message)
  defp state(id), do: Server.get_state(id)

  # ---------------------------------------------------------------------------
  # Registry + supervision
  # ---------------------------------------------------------------------------

  describe "registry" do
    test "server registers under decision ID", %{id: id} do
      start(id)
      assert is_pid(Server.whereis(id))
    end

    test "duplicate start for same ID returns existing pid", %{id: id} do
      {:ok, pid1} = DecisionSup.start_decision(id, "alice", "topic")

      assert {:error, {:already_started, ^pid1}} =
               DecisionSup.start_decision(id, "alice", "topic")
    end

    test "whereis returns nil for unknown ID" do
      assert Server.whereis("does-not-exist-#{:rand.uniform(9999)}") == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Initial state
  # ---------------------------------------------------------------------------

  describe "initial state" do
    test "creator is in connected and joined", %{id: id} do
      start(id, "alice")
      d = state(id)
      assert "alice" in d.connected
      assert "alice" in d.stage.joined
    end

    test "starts in Lobby stage", %{id: id} do
      start(id)
      d = state(id)
      assert %Stage.Lobby{} = d.stage
    end
  end

  # ---------------------------------------------------------------------------
  # Message passing
  # ---------------------------------------------------------------------------

  describe "handle_message" do
    test "valid message returns :ok", %{id: id} do
      start(id, "alice")
      assert :ok = msg(id, {:ready, "alice"})
    end

    test "invalid message returns {:error, reason}", %{id: id} do
      start(id, "alice")

      capture_log(fn ->
        assert {:error, _} = msg(id, {:ready, "charlie"})
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Broadcast effect
  # ---------------------------------------------------------------------------

  describe "broadcast effect" do
    test "state change broadcasts to decision topic", %{id: id} do
      start(id, "alice")
      Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "decision:#{id}")
      msg(id, {:ready, "alice"})
      assert_receive {:decision_updated, decision}, 500
      assert "alice" in decision.stage.ready
    end
  end

  # ---------------------------------------------------------------------------
  # Disconnect
  # ---------------------------------------------------------------------------

  describe "disconnect" do
    test "participant disconnect removes from connected set", %{id: id} do
      start(id, "alice")
      d_before = state(id)
      assert "alice" in d_before.connected

      Server.disconnect(id, "alice")
      Process.sleep(10)
      d_after = state(id)
      refute "alice" in d_after.connected
    end

    test "disconnect on unknown decision does not crash", %{id: _id} do
      assert :ok = Server.disconnect("no-such-decision", "alice")
    end
  end

  # ---------------------------------------------------------------------------
  # LLM integration (debounce + async_llm)
  # ---------------------------------------------------------------------------

  describe "llm integration" do
    # Walk decision through lobby -> scenario, then submit two scenario rephrases
    # to trigger the synthesis debounce.
    # We verify the debounce fires and stores a synthesis result.
    # Uses real LLM only if ANTHROPIC_API_KEY is set; skips gracefully otherwise.

    @tag :llm
    test "synthesis debounce fires and stores result", %{id: id} do
      start(id, "alice")
      msg(id, {:lobby_update, "alice", "where to eat?", []})
      msg(id, {:ready, "alice"})
      msg(id, {:start, "alice"})

      # Submit two rephrases to trigger debounce
      msg(id, {:submit_scenario, "alice", "where should we eat tonight?"})
      msg(id, {:submit_scenario, "bob", "what restaurant for dinner?"})

      # Debounce is 0ms in test env, mock LLM is instant
      Process.sleep(20)
      d = state(id)
      assert %Stage.Scenario{} = d.stage
      assert d.stage.synthesis != nil
    end
  end
end
