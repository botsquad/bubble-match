defmodule BubbleExpr.ParserTest do
  use ExUnit.Case

  alias BubbleExpr.Parser

  @valid [
    "abc def (a)",
    "x y (a \"hello World\" San | b (y | x) c)",
    "a [0] b",
    "a [1+] b",
    "a [1-2=lala] b",
    "(hello | hi) world [End]",
    "[Start] [1-2] hello",
    "world[1-2]",
    "this is a /regex/"
  ]

  test "parser" do
    for sentence <- @valid do
      assert {:ok, ast} = Parser.parse(sentence)
      # IO.puts("")
      # IO.puts("----------")
      # IO.inspect(sentence, label: "sentence")
      # IO.inspect(ast, label: "ast")
    end
  end

  test "p2" do
    #    Parser.parse("[Start] hello[=aa] [0-1=xx] world (a b | b c d)")
    Parser.parse("(hello world)[=a]")
    #    |> IO.inspect(label: "x")
  end
end
