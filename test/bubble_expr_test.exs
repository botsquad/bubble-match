defmodule BubbleExprTest do
  use ExUnit.Case

  test "match" do
    assert {:match, %{}} == BubbleExpr.match("hello", "hello")
  end

  test "parse" do
    assert {:ok, %BubbleExpr{}} = BubbleExpr.parse("hello (there | world)")
    assert {:error, _} = BubbleExpr.parse("hello (")
  end

  test "parse!" do
    assert %BubbleExpr{} = BubbleExpr.parse!("hello (there | world)")
    assert_raise BubbleExpr.ParseError, fn -> BubbleExpr.parse!("hello (") end
  end
end
