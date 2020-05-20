defmodule BubbleMatchTest do
  use ExUnit.Case

  test "match" do
    assert {:match, %{}} == BubbleMatch.match("hello", "hello")
  end

  test "parse" do
    assert {:ok, %BubbleMatch{}} = BubbleExpr.parse("hello (there | world)")
    assert {:error, _} = BubbleMatch.parse("hello (")
  end

  test "parse!" do
    assert %BubbleMatch{} = BubbleExpr.parse!("hello (there | world)")
    assert_raise BubbleMatch.ParseError, fn -> BubbleExpr.parse!("hello (") end
  end
end
