defmodule MaudeLibsWeb.CanvasLiveTest do
  use MaudeLibsWeb.ConnCase, async: false

  import MaudeLibs.DecisionHelpers

  defp mount_as(user) do
    conn = build_conn() |> init_test_session(%{"username" => user})
    live(conn, "/canvas")
  end

  describe "mount" do
    test "redirects to /join when no session username" do
      {:error, {:live_redirect, %{to: "/join"}}} = live(build_conn(), "/canvas")
    end

    test "mounts with valid session" do
      {:ok, view, html} = mount_as("alice")
      assert html =~ "alice"
      assert has_element?(view, "a[href=\"/d/new\"]")
    end
  end

  describe "invite" do
    test "shows invite modal when user is invited" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, view, _html} = mount_as("bob")

      # Simulate an invite broadcast
      send(view.pid, {:invited, decision.id, "Dinner?"})

      html = render(view)
      assert html =~ "been invited"
      assert html =~ "Dinner?"
      assert html =~ "Join"
    end

    test "dismiss_invite clears the modal" do
      decision = seed_decision(:lobby, ["alice", "bob"])
      {:ok, view, _html} = mount_as("bob")

      send(view.pid, {:invited, decision.id, "Dinner?"})
      assert render(view) =~ "been invited"

      view |> element("button", "Later") |> render_click()
      refute render(view) =~ "been invited"
    end
  end

  describe "canvas updates" do
    test "canvas_updated message updates state" do
      {:ok, view, _html} = mount_as("alice")

      circles = %{"d-1" => %{title: "Lunch", tagline: "Eat!", stage: :lobby}}
      send(view.pid, {:canvas_updated, circles})

      # The view stays alive after receiving the message
      assert Process.alive?(view.pid)
    end
  end
end
