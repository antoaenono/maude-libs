defmodule MaudeLibsWeb.StageLayoutTest do
  use ExUnit.Case, async: true

  alias MaudeLibsWeb.StageLayout

  # ---------------------------------------------------------------------------
  # compute/2 - returns {your_pos, others_map}
  # ---------------------------------------------------------------------------

  describe "compute/2" do
    test "returns empty map for no other users" do
      {your_pos, others} = StageLayout.compute([], %{})
      assert others == %{}
      assert {x, y} = your_pos
      assert is_float(x)
      assert is_float(y)
    end

    test "returns one position for one other user" do
      {_your_pos, others} = StageLayout.compute(["bob"], %{})
      assert map_size(others) == 1
      assert {x, y} = others["bob"]
      assert is_float(x)
      assert is_float(y)
    end

    test "returns positions for multiple users" do
      {_your_pos, others} = StageLayout.compute(["bob", "charlie", "dave"], %{})
      assert map_size(others) == 3
      assert Map.has_key?(others, "bob")
      assert Map.has_key?(others, "charlie")
      assert Map.has_key?(others, "dave")
    end

    test "positions are within virtual pixel bounds" do
      {_your_pos, others} = StageLayout.compute(["b", "c", "d"], %{})

      for {_user, {x, y}} <- others do
        assert x >= 80.0 and x <= 920.0, "x=#{x} out of bounds"
        assert y >= 35.0 and y <= 574.0, "y=#{y} out of bounds"
      end
    end

    test "no two users overlap (positions differ)" do
      {_your_pos, others} = StageLayout.compute(["b", "c", "d"], %{})
      positions = Map.values(others)
      assert length(Enum.uniq(positions)) == length(positions)
    end

    test "positions are deterministic for same inputs" do
      ctx = %{has_content: false}
      r1 = StageLayout.compute(["bob", "charlie"], ctx)
      r2 = StageLayout.compute(["bob", "charlie"], ctx)
      assert r1 == r2
    end

    test "order of usernames does not affect positions" do
      ctx = %{}
      r1 = StageLayout.compute(["bob", "charlie"], ctx)
      r2 = StageLayout.compute(["charlie", "bob"], ctx)
      assert r1 == r2
    end
  end

  # ---------------------------------------------------------------------------
  # Claude radius varies with stage context
  # ---------------------------------------------------------------------------

  describe "claude radius affects layout" do
    test "different claude contexts produce different positions" do
      small_ctx = %{}
      large_ctx = %{has_content: true, suggestion_count: 3}
      users = ["bob", "charlie", "dave"]

      {_your_small, small} = StageLayout.compute(users, small_ctx)
      {_your_large, large} = StageLayout.compute(users, large_ctx)

      # At least one user should be at a different position
      any_different =
        Enum.any?(users, fn u ->
          small[u] != large[u]
        end)

      assert any_different, "different claude radius should affect at least one position"
    end

    test "positions remain in virtual pixel bounds regardless of claude size" do
      for ctx <- [%{}, %{is_thinking: true}, %{has_content: true, suggestion_count: 3}] do
        {_your_pos, others} = StageLayout.compute(["b", "c", "d"], ctx)

        for {_user, {x, y}} <- others do
          assert x >= 80.0 and x <= 920.0
          assert y >= 35.0 and y <= 574.0
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Participants stay above "your card" position
  # ---------------------------------------------------------------------------

  describe "vertical positioning" do
    test "all participants positioned above your card" do
      {your_pos, others} = StageLayout.compute(["b", "c", "d"], %{})
      {_yx, yy} = your_pos

      for {_user, {_x, y}} <- others do
        assert y < yy, "participant y=#{y} should be above your card y=#{yy}"
      end
    end

    test "participants positioned above claude center" do
      {_cx, cy} = StageLayout.claude_pos()
      {_your_pos, others} = StageLayout.compute(["b", "c"], %{})

      # At least some should be above claude (they start in upper arc)
      above = Enum.count(others, fn {_user, {_x, y}} -> y < cy end)
      assert above > 0
    end
  end

  # ---------------------------------------------------------------------------
  # Fixed positions
  # ---------------------------------------------------------------------------

  describe "fixed positions" do
    test "claude_pos returns center virtual pixel coordinates" do
      {x, y} = StageLayout.claude_pos()
      assert x == 500.0
      assert y == 350.0
    end

    test "your card is positioned below claude" do
      {your_pos, _others} = StageLayout.compute([], %{})
      {_cx, cy} = StageLayout.claude_pos()
      {_yx, yy} = your_pos
      assert yy > cy, "your card y=#{yy} should be below claude y=#{cy}"
    end

    test "virtual_size returns the canonical canvas dimensions" do
      assert StageLayout.virtual_size() == {1000, 700}
    end
  end
end
