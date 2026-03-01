defmodule MaudeLibsWeb.Dev.SeedController do
  use MaudeLibsWeb, :controller

  alias MaudeLibs.DecisionHelpers

  @valid_stages ~w(lobby scenario priorities options scaffolding dashboard complete)

  def create(conn, %{"stage" => stage_str} = params) when stage_str in @valid_stages do
    users =
      params |> Map.get("users", "alice,bob") |> String.split(",") |> Enum.map(&String.trim/1)

    topic = Map.get(params, "topic", "Where should we eat?")
    user = hd(users)

    stage = String.to_atom(stage_str)
    decision = DecisionHelpers.seed_decision(stage, users, topic: topic)

    MaudeLibs.UserRegistry.register(user)

    conn
    |> put_session(:username, user)
    |> redirect(to: ~p"/d/#{decision.id}")
  end
end
