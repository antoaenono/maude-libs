defmodule MaudeLibs.UserRegistryTest do
  use ExUnit.Case, async: false

  alias MaudeLibs.UserRegistry

  describe "register/1" do
    test "registers a new username" do
      username = "reg-#{:erlang.unique_integer([:positive])}"
      UserRegistry.register(username)
      # Cast is async, give it a moment
      Process.sleep(5)
      assert username in UserRegistry.list_usernames()
    end

    test "duplicate registration does not crash" do
      username = "dup-#{:erlang.unique_integer([:positive])}"
      UserRegistry.register(username)
      UserRegistry.register(username)
      Process.sleep(5)
      # Should appear exactly once in the list
      count = Enum.count(UserRegistry.list_usernames(), &(&1 == username))
      assert count == 1
    end
  end

  describe "list_usernames/0" do
    test "returns a list" do
      result = UserRegistry.list_usernames()
      assert is_list(result)
    end

    test "includes previously registered usernames" do
      u1 = "list-#{:erlang.unique_integer([:positive])}"
      u2 = "list-#{:erlang.unique_integer([:positive])}"
      UserRegistry.register(u1)
      UserRegistry.register(u2)
      Process.sleep(5)
      names = UserRegistry.list_usernames()
      assert u1 in names
      assert u2 in names
    end
  end
end
