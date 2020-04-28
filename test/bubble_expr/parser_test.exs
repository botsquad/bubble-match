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

  test "entity" do
    {:ok, %{ast: ast}} = Parser.parse("[person=a]", expand: false)
    assert [{:entity, "person", [assign: "a"]}] = ast
  end

  test "entities get implicit variable capture" do
    {:ok, %{ast: ast}} = Parser.parse("[PERSON]")
    assert [_, {:entity, "PERSON", [assign: "person"]}] = ast

    {:ok, %{ast: ast}} = Parser.parse("([PERSON])")
    assert [_, {:or, [[{:entity, "PERSON", [assign: "person"]}]], []}] = ast
  end

  test "do not error in invalid regex" do
    assert {:error, _} = Parser.parse("/f[/")
  end
end
