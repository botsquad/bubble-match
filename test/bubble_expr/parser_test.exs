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
    "< a < b c > > d",
    "@foo[=a]",
    "@foo.bar @bla hello (@foo | @bar)"
  ]

  @invalid [
    "(",
    "() )",
    "@fofdsfs+fdsfds"
  ]

  test "parser" do
    assert {:ok, %{ast: nil}} = parse("")

    for sentence <- @valid do
      assert {:ok, _ast} = parse(sentence)
    end

    for sentence <- @invalid do
      assert {:error, _message} = parse(sentence)
    end
  end

  test "entity" do
    {:ok, %{ast: ast}} = parse("[person=a]")
    assert [{:entity, "person", [assign: "a"]}] = ast
  end

  test "entities get implicit variable capture" do
    {:ok, %{ast: ast}} = Parser.parse("[PERSON]")
    assert [_, {:entity, "PERSON", [assign: "person"]}] = ast

    {:ok, %{ast: ast}} = Parser.parse("([PERSON])")
    assert [_, {:or, [[{:entity, "PERSON", [assign: "person"]}]], []}] = ast
  end

  test "do not error in invalid regex" do
    assert {:error, _} = parse("/f[/")
  end

  test "range" do
    assert {:ok, %{ast: [{:any, [], [repeat: {2, 4, :greedy}]}]}} = parse("[2-4]")

    assert {:ok, %{ast: [{:any, [], [repeat: {2, 4, :nongreedy}]}]}} = parse("[2-4?]")
  end

  test "underscore" do
    assert {:ok, %{ast: [{:any, [], [repeat: {0, 5, :greedy}]}]}} = parse("_")
  end

  test "@concept" do
    assert {:ok, %{ast: [_, {:concept, {"intent", "foo"}, []}, _]}} =
             parse("hello @intent.foo name")
  end

  test "@concept compiler" do
    compiler = fn {"intent", "foo"} ->
      send(self(), {:compiled, :x})
      {:ok, {:m, :f, :a}}
    end

    assert {:ok, %{ast: [_, {:concept, {:m, :f, :a}, []}]}} =
             Parser.parse("@intent.foo", concepts_compiler: compiler)

    assert_receive({:compiled, _})
  end

  test "@concept compiler error case" do
    assert {:error, _} = Parser.parse("@foo")

    compiler = fn _ ->
      nil
    end

    assert {:error, "concepts_compiler " <> _} =
             Parser.parse("@intent.foo", concepts_compiler: compiler)
  end

  ###

  defp parse(str), do: Parser.parse(str, expand: false)
end
