defmodule MaudeLibs.Decision.ServerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mox

  alias MaudeLibs.Decision.Server
  alias MaudeLibs.Decision.Supervisor, as: DecisionSup
  alias MaudeLibs.Decision.Stage

  setup :set_mox_global
  setup :verify_on_exit!

  # Each test gets a unique decision ID to avoid registry conflicts
  setup do
    MaudeLibs.LLM.MockStubs.stub_all()
    id = "test-#{:erlang.unique_integer([:positive])}"
    {:ok, id: id}
  end

  defp start(id, creator \\ "alice", topic \\ "dinner?") do
    {:ok, _pid} = DecisionSup.start_decision(id, creator, topic)
    id
  end

  defp msg(id, message), do: Server.handle_message(id, message)
  defp state(id), do: Server.get_state(id)

  defp do_await(pred, timeout) do
    receive do
      {:decision_updated, d} ->
        if pred.(d), do: d, else: do_await(pred, timeout)
    after
      timeout -> flunk("timed out waiting for matching broadcast")
    end
  end

  # Subscribe first, then run action, then drain
  defp subscribe_and_run(id, action_fn, pred, timeout \\ 500) do
    Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "decision:#{id}")
    action_fn.()
    do_await(pred, timeout)
  end

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

      d =
        subscribe_and_run(id, fn -> msg(id, {:ready, "alice"}) end, fn d ->
          "alice" in d.stage.ready
        end)

      assert "alice" in d.stage.ready
    end
  end

  # ---------------------------------------------------------------------------
  # Disconnect
  # ---------------------------------------------------------------------------

  describe "disconnect" do
    test "participant disconnect removes from connected set", %{id: id} do
      start(id, "alice")

      subscribe_and_run(id, fn -> Server.disconnect(id, "alice") end, fn d ->
        not MapSet.member?(d.connected, "alice")
      end)
    end

    test "disconnect on unknown decision does not crash", %{id: _id} do
      assert :ok = Server.disconnect("no-such-decision", "alice")
    end
  end

  describe "disconnect grace period" do
    setup do
      prev = Application.get_env(:maude_libs, :disconnect_grace_ms)
      Application.put_env(:maude_libs, :disconnect_grace_ms, 200)
      on_exit(fn -> Application.put_env(:maude_libs, :disconnect_grace_ms, prev || 0) end)
      :ok
    end

    test "user stays connected during grace period", %{id: id} do
      start(id, "alice")
      Server.disconnect(id, "alice")
      # Should still be connected immediately after disconnect
      d = state(id)
      assert "alice" in d.connected
    end

    test "reconnect within grace cancels disconnect", %{id: id} do
      start(id, "alice")
      Server.disconnect(id, "alice")
      msg(id, {:connect, "alice"})
      # Wait past the grace period
      Process.sleep(300)
      d = state(id)
      assert "alice" in d.connected
    end

    test "user disconnected after grace expires", %{id: id} do
      start(id, "alice")
      Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "decision:#{id}")
      Server.disconnect(id, "alice")

      # Wait for the grace period to expire and disconnect to broadcast
      receive do
        {:decision_updated, d} ->
          refute "alice" in d.connected
      after
        500 -> flunk("timed out waiting for disconnect broadcast")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # LLM integration (debounce + async_llm)
  # ---------------------------------------------------------------------------

  describe "llm integration" do
    @tag :llm
    test "synthesis debounce fires and stores result", %{id: id} do
      start(id, "alice")
      msg(id, {:lobby_update, "alice", "where to eat?", []})
      msg(id, {:ready, "alice"})
      msg(id, {:start, "alice"})

      # Subscribe before triggering debounce
      d =
        subscribe_and_run(
          id,
          fn ->
            msg(id, {:submit_scenario, "alice", "where should we eat tonight?"})
            msg(id, {:submit_scenario, "bob", "what restaurant for dinner?"})
          end,
          fn d ->
            d.stage.synthesis != nil
          end
        )

      assert is_binary(d.stage.synthesis)
    end
  end

  # ---------------------------------------------------------------------------
  # Async LLM: priority suggestions
  # ---------------------------------------------------------------------------

  describe "async LLM: priority suggestions" do
    test "suggestions arrive after all confirm", %{id: id} do
      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        stage: %Stage.Priorities{
          priorities: %{"alice" => %{text: "cost", direction: "-"}}
        }
      }

      DecisionSup.start_with_state(decision)

      d =
        subscribe_and_run(
          id,
          fn ->
            msg(id, {:confirm_priority, "alice"})
          end,
          fn d ->
            d.stage.suggestions != []
          end
        )

      assert length(d.stage.suggestions) == 3
      assert d.stage.suggesting == false
    end
  end

  # ---------------------------------------------------------------------------
  # Async LLM: option suggestions
  # ---------------------------------------------------------------------------

  describe "async LLM: option suggestions" do
    test "suggestions arrive after all confirm", %{id: id} do
      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        priorities: [%{id: "+1", text: "speed", direction: "+"}],
        stage: %Stage.Options{
          proposals: %{"alice" => %{name: "tacos", desc: "quick tacos"}}
        }
      }

      DecisionSup.start_with_state(decision)

      d =
        subscribe_and_run(
          id,
          fn ->
            msg(id, {:confirm_option, "alice"})
          end,
          fn d ->
            match?(%Stage.Options{suggestions: [_ | _]}, d.stage)
          end
        )

      assert length(d.stage.suggestions) == 3
      assert d.stage.suggesting == false
    end
  end

  # ---------------------------------------------------------------------------
  # Async LLM: scaffolding
  # ---------------------------------------------------------------------------

  describe "async LLM: scaffolding" do
    test "scaffolding result advances to dashboard", %{id: id} do
      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        priorities: [%{id: "+1", text: "speed", direction: "+"}],
        stage: %Stage.Options{
          proposals: %{"alice" => %{name: "tacos", desc: "x"}}
        }
      }

      DecisionSup.start_with_state(decision)

      d =
        subscribe_and_run(
          id,
          fn ->
            msg(id, {:ready_options, "alice"})
          end,
          fn d ->
            match?(%Stage.Dashboard{}, d.stage)
          end
        )

      assert length(d.stage.options) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # Async LLM: why_statement
  # ---------------------------------------------------------------------------

  describe "async LLM: why_statement" do
    test "why_statement stored on complete stage", %{id: id} do
      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        stage: %Stage.Dashboard{
          options: [
            %{name: "tacos", desc: "x", for: [], against: []},
            %{name: "pizza", desc: "y", for: [], against: []}
          ],
          votes: %{"alice" => ["tacos"]}
        }
      }

      DecisionSup.start_with_state(decision)

      d =
        subscribe_and_run(
          id,
          fn ->
            msg(id, {:ready_dashboard, "alice"})
          end,
          fn d ->
            match?(%Stage.Complete{why_statement: s} when is_binary(s), d.stage)
          end
        )

      assert d.stage.why_statement =~ "tacos"
    end
  end

  # ---------------------------------------------------------------------------
  # Tagline side effect
  # ---------------------------------------------------------------------------

  describe "tagline" do
    test "canvas circle gets tagline after scenario resolution", %{id: id} do
      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        stage: %Stage.Scenario{
          submissions: %{"alice" => "dinner?"},
          votes: %{}
        }
      }

      DecisionSup.start_with_state(decision)
      # Tagline updates canvas via CanvasServer which broadcasts on "canvas"
      Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "canvas")
      msg(id, {:vote_scenario, "alice", "dinner?"})

      # Drain canvas broadcasts until we see one with the tagline set
      assert_tagline_broadcast(id)
    end
  end

  defp assert_tagline_broadcast(id) do
    receive do
      {:canvas_updated, canvas} ->
        if canvas[id] && canvas[id].tagline != nil do
          assert canvas[id].tagline == "Decision Time"
        else
          assert_tagline_broadcast(id)
        end
    after
      500 -> flunk("timed out waiting for tagline canvas broadcast")
    end
  end

  # ---------------------------------------------------------------------------
  # LLM error handling: error mock
  # ---------------------------------------------------------------------------

  describe "LLM error: synthesis" do
    setup do
      Hammox.expect(MaudeLibs.LLM.MockBehaviour, :synthesize_scenario, fn _submissions ->
        {:error, :api_down}
      end)

      :ok
    end

    @tag capture_log: true
    test "synthesis error broadcasts {:llm_error, _} on decision topic", %{id: id} do
      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice", "bob"]),
        stage: %Stage.Scenario{
          submissions: %{"alice" => "where?"}
        }
      }

      DecisionSup.start_with_state(decision)
      Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "decision:#{id}")

      # Submit a second scenario to trigger debounced synthesis
      msg(id, {:submit_scenario, "bob", "what restaurant?"})

      assert_receive {:llm_error, :api_down}, 2000
    end
  end

  describe "LLM error: scaffolding" do
    setup do
      Hammox.expect(MaudeLibs.LLM.MockBehaviour, :scaffold, fn _scenario, _priorities, _options ->
        {:error, :api_down}
      end)

      :ok
    end

    @tag capture_log: true
    test "scaffold error keeps stage as Scaffolding", %{id: id} do
      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        priorities: [%{id: "+1", text: "speed", direction: "+"}],
        stage: %Stage.Options{
          proposals: %{"alice" => %{name: "tacos", desc: "x"}}
        }
      }

      DecisionSup.start_with_state(decision)

      d =
        subscribe_and_run(
          id,
          fn -> msg(id, {:ready_options, "alice"}) end,
          fn d -> d.stage.llm_error == true end,
          2000
        )

      assert %Stage.Scaffolding{} = d.stage
      assert d.stage.llm_error == true
    end

    @tag capture_log: true
    test "scaffold error sets llm_error on stage", %{id: id} do
      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        priorities: [%{id: "+1", text: "speed", direction: "+"}],
        stage: %Stage.Options{
          proposals: %{"alice" => %{name: "tacos", desc: "x"}}
        }
      }

      DecisionSup.start_with_state(decision)

      d =
        subscribe_and_run(
          id,
          fn -> msg(id, {:ready_options, "alice"}) end,
          fn d -> d.stage.llm_error == true end,
          2000
        )

      assert d.stage.llm_error == true
    end
  end

  describe "LLM error: scaffold retry" do
    test "retry with normal Mock advances to Dashboard", %{id: id} do
      # Start in a Scaffolding stage with llm_error and stored args
      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        priorities: [%{id: "+1", text: "speed", direction: "+"}],
        stage: %Stage.Scaffolding{
          llm_error: true,
          scaffold_topic: "dinner?",
          scaffold_priorities: [%{id: "+1", text: "speed", direction: "+"}],
          scaffold_options: [%{name: "tacos", desc: "x"}]
        }
      }

      DecisionSup.start_with_state(decision)

      d =
        subscribe_and_run(
          id,
          fn -> msg(id, :retry_scaffold) end,
          fn d -> match?(%Stage.Dashboard{}, d.stage) end,
          2000
        )

      assert %Stage.Dashboard{} = d.stage
      assert length(d.stage.options) > 0
    end
  end

  describe "LLM error: why_statement" do
    setup do
      Hammox.expect(MaudeLibs.LLM.MockBehaviour, :why_statement, fn _scenario,
                                                                    _priorities,
                                                                    _winner,
                                                                    _vote_counts ->
        {:error, :api_down}
      end)

      :ok
    end

    @tag capture_log: true
    test "why_statement error sets llm_error on Complete stage", %{id: id} do
      decision = %MaudeLibs.Decision.Core{
        id: id,
        creator: "alice",
        topic: "dinner?",
        connected: MapSet.new(["alice"]),
        stage: %Stage.Dashboard{
          options: [
            %{name: "tacos", desc: "x", for: [], against: []},
            %{name: "pizza", desc: "y", for: [], against: []}
          ],
          votes: %{"alice" => ["tacos"]}
        }
      }

      DecisionSup.start_with_state(decision)

      d =
        subscribe_and_run(
          id,
          fn -> msg(id, {:ready_dashboard, "alice"}) end,
          fn d -> match?(%Stage.Complete{llm_error: true}, d.stage) end,
          2000
        )

      assert d.stage.llm_error == true
      assert d.stage.why_statement == nil
    end
  end

  # ---------------------------------------------------------------------------
  # LLM error resilience
  # ---------------------------------------------------------------------------

  describe "LLM error resilience" do
    test "server survives :noop llm_result", %{id: id} do
      {:ok, pid} = DecisionSup.start_decision(id, "alice", "dinner?")
      send(pid, {:llm_result, :noop})
      assert Process.alive?(pid)
      assert state(id) != nil
    end

    test "server survives llm_result for wrong stage", %{id: id} do
      {:ok, pid} = DecisionSup.start_decision(id, "alice", "dinner?")

      capture_log(fn ->
        send(pid, {:llm_result, {:synthesis_result, "text"}})
        # Drain the GenServer mailbox with a sync call
        _ = state(id)
      end)

      assert Process.alive?(pid)
    end
  end

  # ---------------------------------------------------------------------------
  # Invited user notifications
  # ---------------------------------------------------------------------------

  describe "invite notifications" do
    test "invited but not yet joined users get notified", %{id: id} do
      start(id, "alice")
      Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "user:bob")
      msg(id, {:lobby_update, "alice", "dinner?", ["bob"]})
      assert_receive {:invited, ^id, "dinner?"}, 100
    end

    test "already joined users do not get re-notified", %{id: id} do
      start(id, "alice")
      msg(id, {:lobby_update, "alice", "dinner?", ["bob"]})
      msg(id, {:join, "bob"})

      Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "user:bob")
      msg(id, {:ready, "alice"})

      refute_receive {:invited, ^id, _}, 50
    end
  end

  # ---------------------------------------------------------------------------
  # Supervision
  # ---------------------------------------------------------------------------

  describe "supervision" do
    test "stop_decision terminates the server", %{id: id} do
      start(id)
      pid = Server.whereis(id)
      assert is_pid(pid)
      ref = Process.monitor(pid)
      DecisionSup.stop_decision(id)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 100
    end

    test "stop nonexistent decision is :ok" do
      assert :ok = DecisionSup.stop_decision("no-such-#{System.unique_integer()}")
    end
  end
end
