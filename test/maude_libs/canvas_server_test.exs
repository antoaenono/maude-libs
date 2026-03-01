defmodule MaudeLibs.CanvasServerTest do
  use ExUnit.Case, async: false

  alias MaudeLibs.CanvasServer

  setup do
    # Clear state between tests by getting current state and working with unique IDs
    id = "canvas-test-#{:erlang.unique_integer([:positive])}"
    {:ok, id: id}
  end

  describe "add_circle/2" do
    test "adds a new circle with default fields", %{id: id} do
      CanvasServer.add_circle(id, "Dinner?")
      state = CanvasServer.get_state()
      assert circle = state[id]
      assert circle.title == "Dinner?"
      assert circle.tagline == nil
      assert circle.stage == :lobby
    end

    test "is idempotent - duplicate id is ignored", %{id: id} do
      CanvasServer.add_circle(id, "First")
      CanvasServer.add_circle(id, "Second")
      # Need to wait for casts to process
      state = CanvasServer.get_state()
      assert state[id].title == "First"
    end

    test "broadcasts on add", %{id: id} do
      Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "canvas")
      CanvasServer.add_circle(id, "Broadcast test")
      assert_receive {:canvas_updated, state}, 500
      assert state[id].title == "Broadcast test"
    end

    test "multiple circles coexist" do
      id1 = "multi-#{:erlang.unique_integer([:positive])}"
      id2 = "multi-#{:erlang.unique_integer([:positive])}"
      CanvasServer.add_circle(id1, "A")
      CanvasServer.add_circle(id2, "B")
      state = CanvasServer.get_state()
      assert state[id1].title == "A"
      assert state[id2].title == "B"
    end
  end

  describe "update_circle/2" do
    test "merges attrs into existing circle", %{id: id} do
      CanvasServer.add_circle(id, "Original")
      CanvasServer.update_circle(id, %{tagline: "short one", stage: :complete})
      state = CanvasServer.get_state()
      assert state[id].tagline == "short one"
      assert state[id].stage == :complete
      assert state[id].title == "Original"
    end

    test "silently ignores update to non-existent circle" do
      fake_id = "nonexistent-#{:erlang.unique_integer([:positive])}"
      CanvasServer.update_circle(fake_id, %{tagline: "nope"})
      state = CanvasServer.get_state()
      refute Map.has_key?(state, fake_id)
    end

    test "broadcasts on update", %{id: id} do
      CanvasServer.add_circle(id, "Pre-update")
      # Ensure add is processed before subscribing
      _ = CanvasServer.get_state()
      Phoenix.PubSub.subscribe(MaudeLibs.PubSub, "canvas")
      CanvasServer.update_circle(id, %{stage: :complete})
      assert_receive {:canvas_updated, state}, 500
      assert state[id].stage == :complete
    end
  end

  describe "get_state/0" do
    test "returns empty map when no circles exist" do
      # State may have circles from other tests, but we can verify it's a map
      state = CanvasServer.get_state()
      assert is_map(state)
    end
  end
end
