defmodule BubbleExpr.ParserTest do
  use ExUnit.Case

  alias BubbleExpr.Parser

  @valid [
    "abc def (a)",
    "x y (a \"hello World\" San | b (y | x) c)",
    "a [0] b",
    "a [1-2;=lala] b",
    "(hello | hi) world [End]",
    "world[1-2]"
  ]

  test "parser" do
    for sentence <- @valid do
      assert {:ok, _ast} = Parser.parse(sentence)
    end
  end
end
