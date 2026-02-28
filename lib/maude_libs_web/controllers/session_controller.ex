defmodule MaudeLibsWeb.SessionController do
  use MaudeLibsWeb, :controller

  def create(conn, %{"username" => username}) do
    username = String.trim(username)

    cond do
      username == "" ->
        conn
        |> put_flash(:error, "Username is required")
        |> redirect(to: ~p"/join")

      String.length(username) > 8 ->
        conn
        |> put_flash(:error, "Username must be 8 characters or less")
        |> redirect(to: ~p"/join")

      not String.match?(username, ~r/^[a-zA-Z0-9]+$/) ->
        conn
        |> put_flash(:error, "Letters and numbers only")
        |> redirect(to: ~p"/join")

      true ->
        MaudeLibs.UserRegistry.register(username)

        conn
        |> put_session(:username, username)
        |> redirect(to: ~p"/canvas")
    end
  end
end
