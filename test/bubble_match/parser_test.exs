defmodule BubbleMatch.ParserTest do
  use ExUnit.Case

  alias BubbleMatch.Parser

  @valid [
    "",
    "  ",
    "abc def (a)",
    "(a|b)",
    "x y (a \"hello World\" San | b (y | x) c)",
    "a [0] b",
    "(a|b)",
    "( a|b|c )  ",
    "a-bc | foo",
    "a [1+] b",
    "a [1-2=lala] b",
    "(hello | hi) world [End]",
    "[Start] [1-2] hello",
    "world[1-2]",
    "a?",
    "(a | b)?",
    "/^\\/quit$/",
    "this is a /regex/",
    "%VERB",
    "😍",
    "< a < b c > > d",
    "@foo[=a]",
    "this is a \"literal\" sentence ",
    "this is a 'single quoted' literal",
    "[phone_number]",
    "a | b c (d | e)",
    "@foo.bar @bla hello (@foo | @bar)",
    "'harry\\'s burgers'",
    # backward compatibility
    ".*",
    "^abc$"
  ]

  @invalid [
    "a?[1]",
    "(",
    "asdfxx?[assign]",
    "() )",
    "word[ent]",
    "@fofdsfs+fdsfds",
    "[nonexisting]"
  ]

  test "compound nouns" do
    assert {:ok,
            %{
              ast: [
                {:or,
                 [
                   [{:word, "ab", []}],
                   [{:word, "a-b", []}],
                   [{:word, "a", []}, {:word, "b", []}]
                 ], []}
              ]
            }} = parse("a-b")
  end

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
    {:ok, %{ast: ast}} = Parser.parse("[person]")
    assert [_, {:entity, "person", [assign: "person"]}] = ast

    {:ok, %{ast: ast}} = Parser.parse("([person])")
    assert [_, {:or, [[{:entity, "person", [assign: "person"]}]], []}] = ast
  end

  test "do not error in invalid regex" do
    assert {:error, _} = parse("/f[/")
  end

  test "range" do
    assert {:ok, %{ast: [{:any, [], [repeat: {2, 4, :greedy}]}]}} = parse("[2-4]")

    assert {:ok, %{ast: [{:any, [], [repeat: {2, 4, :nongreedy}]}]}} = parse("[2-4?]")
  end

  test "underscore" do
    assert {:ok, %{ast: [{:any, [], [repeat: {0, 5, :nongreedy}]}]}} = parse("_")
  end

  test "pointies" do
    assert [{:any, [], _}, {:or, [[_, _, _], [_, _, _]], _}] = Parser.parse!("< a b >").ast
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

  test "@concept compiler can return expr" do
    compiler = fn {"intent"} ->
      send(self(), {:compiled, :x})
      Parser.parse("hello _ world")
    end

    assert {:ok, %{ast: [_, {:concept, %BubbleMatch{}, [assign: "intent"]}]}} =
             Parser.parse("@intent", concepts_compiler: compiler)

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
