defmodule BubbleExpr.ParserTest do
  use ExUnit.Case

  alias BubbleExpr.Parser

  @valid [
    "abc def (a)",
    "x y (a \"hello World\" San | b (y | x) c)",
    "a [0] b",
    "a [1-2;=lala] b",
    "(hello | hi) world [End]",
    "[Start] [1-2] hello",
    "world[1-2]",
    "this is a /regex/"
  ]

  test "parser" do
    for sentence <- @valid do
      assert {:ok, _ast} = Parser.parse(sentence)
    end
  end

  test "p2" do
    Parser.parse("[Start] hello? [0-1] world (a b | b c d)")
    |> IO.inspect(label: "x")
  end
end
