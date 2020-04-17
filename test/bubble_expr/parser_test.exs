defmodule BubbleExpr.ParserTest do
  use ExUnit.Case

  alias BubbleExpr.Parser

  @valid [
    "",
    "  ",
    "abc def (a)",
    "x y (a \"hello World\" San | b (y | x) c)",
    "a [0] b",
    "a [1+] b",
    "a [1-2=lala] b",
    "(hello | hi) world [End]",
    "[Start] [1-2] hello",
    "world[1-2]",
    "this is a /regex/",
    "< a < b c > > d"
  ]

  @invalid [
    "("
  ]

  test "parser" do
    for sentence <- @valid do
      assert {:ok, _ast} = Parser.parse(sentence)
    end

    for sentence <- @invalid do
      assert {:error, _message} = Parser.parse(sentence)
    end
  end

  test "p2" do
    #    Parser.parse("[Start] hello[=aa] [0-1=xx] world (a b | b c d)")
    Parser.parse("(hello world)[=a]")
    #    |> IO.inspect(label: "x")
  end
end
