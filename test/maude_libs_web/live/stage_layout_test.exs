defmodule MaudeLibsWeb.StageLayoutTest do
  use ExUnit.Case, async: true

  alias MaudeLibsWeb.StageLayout

  # ---------------------------------------------------------------------------
  # compute/2
  # ---------------------------------------------------------------------------

  describe "compute/2" do
    test "returns empty map for no other users" do
      assert StageLayout.compute([], %{}) == %{}
    end

    test "returns one position for one other user" do
      result = StageLayout.compute(["bob"], %{})
      assert map_size(result) == 1
      assert {x, y} = result["bob"]
      assert is_float(x)
      assert is_float(y)
    end

    test "returns positions for multiple users" do
      result = StageLayout.compute(["bob", "charlie", "dave"], %{})
      assert map_size(result) == 3
      assert Map.has_key?(result, "bob")
      assert Map.has_key?(result, "charlie")
      assert Map.has_key?(result, "dave")
    end

    test "positions are within virtual pixel bounds" do
      result = StageLayout.compute(["b", "c", "d"], %{})

      for {_user, {x, y}} <- result do
        assert x >= 80.0 and x <= 920.0, "x=#{x} out of bounds"
        assert y >= 35.0 and y <= 504.0, "y=#{y} out of bounds"
      end
    end

    test "no two users overlap (positions differ)" do
      result = StageLayout.compute(["b", "c", "d"], %{})
      positions = Map.values(result)
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

      small = StageLayout.compute(users, small_ctx)
      large = StageLayout.compute(users, large_ctx)

      # At least one user should be at a different position
      any_different =
        Enum.any?(users, fn u ->
          small[u] != large[u]
        end)

      assert any_different, "different claude radius should affect at least one position"
    end

    test "positions remain in virtual pixel bounds regardless of claude size" do
      for ctx <- [%{}, %{is_thinking: true}, %{has_content: true, suggestion_count: 3}] do
        result = StageLayout.compute(["b", "c", "d"], ctx)

        for {_user, {x, y}} <- result do
          assert x >= 80.0 and x <= 920.0
          assert y >= 35.0 and y <= 504.0
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Participants stay above "your card" position
  # ---------------------------------------------------------------------------

  describe "vertical positioning" do
    test "all participants positioned above your card" do
      {_yx, yy} = StageLayout.your_pos()
      result = StageLayout.compute(["b", "c", "d"], %{})

      for {_user, {_x, y}} <- result do
        assert y < yy, "participant y=#{y} should be above your card y=#{yy}"
      end
    end

    test "participants positioned above claude center" do
      {_cx, cy} = StageLayout.claude_pos()
      result = StageLayout.compute(["b", "c"], %{})

      # At least some should be above claude (they start in upper arc)
      above = Enum.count(result, fn {_user, {_x, y}} -> y < cy end)
      assert above > 0
    end
  end

  # ---------------------------------------------------------------------------
  # Fixed positions
  # ---------------------------------------------------------------------------

  describe "fixed positions" do
    test "claude_pos returns center-ish virtual pixel coordinates" do
      {x, y} = StageLayout.claude_pos()
      assert x == 500.0
      assert y == 315.0
    end

    test "your_pos returns bottom-center virtual pixel coordinates" do
      {x, y} = StageLayout.your_pos()
      assert x == 500.0
      assert y == 616.0
    end

    test "virtual_size returns the canonical canvas dimensions" do
      assert StageLayout.virtual_size() == {1000, 700}
    end
  end

end
