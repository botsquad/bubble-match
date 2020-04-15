defmodule BubbleExprTest do
  use ExUnit.Case
  doctest BubbleExpr

  test "greets the world" do
    assert BubbleExpr.hello() == :world
  end
end
