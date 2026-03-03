defmodule MaudeLibsWeb.SessionControllerTest do
  use MaudeLibsWeb.ConnCase

  describe "POST /session" do
    test "valid alphanumeric username redirects to /canvas", %{conn: conn} do
      conn = post(conn, "/session", %{"username" => "alice"})
      assert redirected_to(conn) == "/canvas"
      assert get_session(conn, :username) == "alice"
    end

    test "valid username registers in UserRegistry", %{conn: conn} do
      username = "sess#{:erlang.unique_integer([:positive])}"
      post(conn, "/session", %{"username" => username})
      # Flush the GenServer mailbox so the cast is processed before we read ETS
      :sys.get_state(MaudeLibs.UserRegistry)
      assert username in MaudeLibs.UserRegistry.list_usernames()
    end

    test "trims whitespace from username", %{conn: conn} do
      conn = post(conn, "/session", %{"username" => "  bob  "})
      assert redirected_to(conn) == "/canvas"
      assert get_session(conn, :username) == "bob"
    end

    test "empty username redirects to /join with error", %{conn: conn} do
      conn = post(conn, "/session", %{"username" => ""})
      assert redirected_to(conn) == "/join"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Username is required"
    end

    test "whitespace-only username treated as empty", %{conn: conn} do
      conn = post(conn, "/session", %{"username" => "   "})
      assert redirected_to(conn) == "/join"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Username is required"
    end

    test "username over 8 chars rejected", %{conn: conn} do
      conn = post(conn, "/session", %{"username" => "abcdefghi"})
      assert redirected_to(conn) == "/join"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "8 characters"
    end

    test "exactly 8 chars is accepted", %{conn: conn} do
      conn = post(conn, "/session", %{"username" => "abcdefgh"})
      assert redirected_to(conn) == "/canvas"
    end

    test "special characters rejected", %{conn: _conn} do
      for bad <- ["al-ice", "al_ice", "al ice", "al!ce", "al@ce", "al.ce"] do
        conn = post(build_conn(), "/session", %{"username" => bad})

        assert redirected_to(conn) == "/join",
               "expected '#{bad}' to be rejected"
      end
    end

    test "unicode characters rejected", %{conn: conn} do
      conn = post(conn, "/session", %{"username" => "caf\u00e9"})
      assert redirected_to(conn) == "/join"
    end

    test "numeric-only username is valid", %{conn: conn} do
      conn = post(conn, "/session", %{"username" => "12345"})
      assert redirected_to(conn) == "/canvas"
    end

    test "mixed case is preserved", %{conn: conn} do
      conn = post(conn, "/session", %{"username" => "AlIcE"})
      assert get_session(conn, :username) == "AlIcE"
    end
  end
end
