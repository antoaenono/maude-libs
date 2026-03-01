defmodule MaudeLibsWeb.DecisionLiveTest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  alias MaudeLibs.Decision.Server

  @moduletag :integration

  defp mount_as(user, decision_id) do
    conn = build_conn() |> init_test_session(%{"username" => user})
    live(conn, "/d/#{decision_id}")
  end

  # ---------------------------------------------------------------------------
  # Mount & Session
  # ---------------------------------------------------------------------------

  describe "mount" do
    @tag stage: :mount
    test "redirects to /join when no session username" do
      conn = build_conn()
      {:error, {:live_redirect, %{to: "/join"}}} = live(conn, "/d/new")
    end

    @tag stage: :mount
    test "redirects to /canvas when decision ID not found" do
      conn = build_conn() |> init_test_session(%{"username" => "alice"})
      {:error, {:live_redirect, %{to: "/canvas"}}} = live(conn, "/d/nonexistent-id")
    end

    @tag stage: :mount
    test "mounts successfully with valid session and existing decision" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, view, html} = mount_as("alice", decision.id)
      assert html =~ "New Decision"
      assert has_element?(view, "button", "Ready up")
    end

    @tag stage: :mount
    test "spectator mode when user not invited" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, view, html} = mount_as("charlie", decision.id)
      assert html =~ "Spectating"
      refute has_element?(view, "button", "Ready up")
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-stage: connect/disconnect
  # ---------------------------------------------------------------------------

  describe "connect/disconnect" do
    @tag stage: :connectivity
    test "disconnect removes user from connected set" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, _view, _} = mount_as("bob", decision.id)

      state = Server.get_state(decision.id)
      assert "bob" in state.connected

      # Disconnect bob
      Server.handle_message(decision.id, {:disconnect, "bob"})

      state = Server.get_state(decision.id)
      refute "bob" in state.connected
    end
  end
end
