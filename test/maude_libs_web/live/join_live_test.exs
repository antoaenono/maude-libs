defmodule MaudeLibsWeb.JoinLiveTest do
  use MaudeLibsWeb.ConnCase, async: true

  test "renders join form" do
    {:ok, view, html} = live(build_conn(), "/join")
    assert html =~ "Maude Libs"
    assert html =~ "Choose a username"
    assert has_element?(view, "button[disabled]", "Join")
  end

  test "typing a username enables the button" do
    {:ok, view, _html} = live(build_conn(), "/join")

    view |> element("form") |> render_change(%{"username" => "alice"})

    refute has_element?(view, "button[disabled]", "Join")
    assert has_element?(view, "button", "Join")
  end

  test "empty username keeps button disabled" do
    {:ok, view, _html} = live(build_conn(), "/join")

    view |> element("form") |> render_change(%{"username" => ""})

    assert has_element?(view, "button[disabled]", "Join")
  end
end
