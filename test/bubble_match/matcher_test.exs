defmodule BubbleMatch.MatcherTest do
  use ExUnit.Case

  alias BubbleMatch.{Matcher, Sentence, Token}

  test "edge cases" do
    assert :nomatch == Matcher.match("", "Hello world!")
  end

  test "matcher" do
    assert {:match, %{}} == Matcher.match("hello", "Hello world!")
    assert {:match, %{}} == Matcher.match("world", "Hello world!")
    assert {:match, %{}} == Matcher.match("hello world", "Hello world!")
    assert {:match, %{}} == Matcher.match("HELLO World", "Hello world!")
    assert :nomatch == Matcher.match("world hello", "Hello world!")
    assert :nomatch == Matcher.match("hello world", "Hello there world!")
    assert :nomatch == Matcher.match("hello world", "Hello there cruel world!")
  end

  test "matcher w/ emoji" do
    assert {:match, %{}} == Matcher.match("😍", "hi 😍")
  end

  test "compound words" do
    assert {:match, %{}} == Matcher.match("was-machine", "wasmachine!")
    assert {:match, %{}} == Matcher.match("was-machine", "was machine!")
    assert {:match, %{}} == Matcher.match("was-machine", "was-machine!")
    assert :nomatch == Matcher.match("was-machine", "wasjes machine!")
  end

  describe "literal" do
    test "literal" do
      assert {:match, %{}} == Matcher.match("\"world\"", "Hello, world")
      assert {:match, %{}} == Matcher.match("\"Hello\"", "Hello world")

      assert :nomatch == Matcher.match("\"wurld\"", "Hello, world")
    end

    test "literal can span multiple tokens" do
      assert {:match, %{}} == Matcher.match("\"Hello, world\"", "Hello, world")

      assert {:match, %{}} == Matcher.match("\"San Francisco\"", "I live in San Francisco, dude.")
      assert :nomatch == Matcher.match("\"San Franci\"", "I live in San Francisco, dude.")

      assert :nomatch == Matcher.match("\"San Francisco\" yo", "I live in San Francisco, dude.")

      assert {:match, %{}} == Matcher.match("\"test sequence\"", "a a a a test sequence,")

      assert {:match, _} = Matcher.match("\"Yo\"[2]", "Yo Yo Yo")
    end

    test "literal is case insensitive" do
      assert {:match, %{}} == Matcher.match("\"Hello\"", "HELLO world")
    end

    test "literal single quoted" do
      assert {:match, %{}} == Matcher.match("'world'", "Hello, world")
      assert {:match, %{}} == Matcher.match("'Hello'", "Hello world")
    end
  end

  describe "regex" do
    test "regex" do
      assert {:match, %{}} == Matcher.match("/\\d+/", "foo 32432")
      assert {:match, %{"x" => [%{raw: "123"}]}} = Matcher.match("/\\d+/[=x]", "la la lala 123")

      assert :nomatch == Matcher.match("/[a-z][a-z]+/", "a")
      assert :nomatch == Matcher.match("/[a-z][a-z]+/", "A1")
    end

    test "regex w/ slash" do
      assert {:match, %{}} == Matcher.match("/\\/quit/", "/quit")
    end

    test "regex is case insensitive" do
      assert {:match, %{}} == Matcher.match("/quit/", "i QUIT")
    end

    test "regex span whitespace" do
      assert {:match, %{}} == Matcher.match("/hello world/", "hello world")
      assert {:match, %{}} == Matcher.match("/hello world/", "hello world lala")

      assert {:match, %{"x" => [a, b]}} =
               Matcher.match("/hello world/[=x]", "wellhello worldieworld")

      assert "wellhello " == a.raw
      assert "worldieworld" == b.raw

      assert {:match, %{"value" => _}} =
               Matcher.match("/[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+/[=value]", "a@a.nl")
    end

    test "regex with capturing" do
      assert {:match, %{"zip" => [t]}} = Matcher.match("/\\d+/[=zip]", "foo 1234 lala")
      assert "1234 " == t.raw
    end
  end

  describe "OR group" do
    test "OR group" do
      assert {:match, %{}} == Matcher.match("(hello | hi) world", "Hello world!")
      assert {:match, %{}} == Matcher.match("(hello | hi) (there | world)", "hi there!")
      assert :nomatch == Matcher.match("(hello | hi) you", "hello me")
    end

    test "OR works on outer level without parens" do
      assert {:match, %{}} == Matcher.match("hi | hello", "Hello world!")
      assert {:match, %{}} == Matcher.match("hi | hello", "Hi world!")
      assert {:match, %{}} == Matcher.match("hi|hello", "Hi world!")
      assert :nomatch == Matcher.match("hi | hello", "world")
    end
  end

  test "permutation group" do
    assert {:match, %{}} == Matcher.match("< hello world >", "Hello world!")
    assert {:match, %{}} == Matcher.match("< hello world >", "world Hello")
    assert {:match, %{}} == Matcher.match("< hello (earth | world) >", "earth Hello")
    assert {:match, %{}} == Matcher.match("< hello (earth | world) >", "hello earth ")
    assert {:match, %{}} == Matcher.match("< hello (earth | world) >", "hello world ")
    assert :nomatch == Matcher.match("< hello (earth | world) >", "earth world ")
  end

  test "capturing" do
    assert {:match, %{"greeting" => tokens}} = Matcher.match("hello[=greeting]", "Hello world!")
    assert [%{raw: "Hello "}] = tokens

    assert {:match, %{"greeting" => tokens}} =
             Matcher.match("(hello world)[=greeting]", "boohoo Hello world! Bye")

    assert [%{raw: "Hello "}, %{raw: "world"}] = tokens

    assert {:match, %{"greeting" => greeting, "planet" => [planet]}} =
             Matcher.match(
               "(hello (world | earth)[=planet])[=greeting]",
               "boohoo Hello world! Bye"
             )

    assert [%{raw: "Hello "}, %{raw: "world"}] = greeting
    assert %{raw: "world"} = planet
  end

  test "[Start]" do
    assert {:match, %{}} = Matcher.match("[Start] hello", "Hello, world!")
    assert :nomatch = Matcher.match("[Start] hello", "Well hello there")
    assert :nomatch = Matcher.match("hello [Start]", "Well hello")
  end

  test "[End]" do
    assert {:match, %{}} = Matcher.match("world [End]", "Hello, world")
    assert :nomatch = Matcher.match("world [End]", "The world is ending")
    assert :nomatch = Matcher.match("[End] world", "The world is ending")
  end

  test "[Start] [End]" do
    assert {:match, %{}} = Matcher.match("[Start] x [End]", "x")
    assert {:match, %{}} = Matcher.match("[Start] [End]", "")
    assert :nomatch = Matcher.match("lala [Start] [End]", "lala")
    assert :nomatch = Matcher.match("[Start] [End]", "lala")
  end

  test "[N]" do
    assert {:match, %{}} = Matcher.match("[1]", "hello")
    assert {:match, %{}} = Matcher.match("[2]", "hello world")
    assert {:match, %{}} = Matcher.match("[2]", "hello world there")
    assert :nomatch = Matcher.match("[2]", "hello")
    assert :nomatch = Matcher.match("[100]", "a b c d e")

    assert {:match, %{}} = Matcher.match("hello [0] world", "Hello world!")
    assert :nomatch = Matcher.match("hello [0] world", "Hello there, world!")

    assert {:match, %{}} = Matcher.match("a [1] c", "a b c")
    assert {:match, %{}} = Matcher.match("a [2] c", "a b b c")

    assert {:match, %{"xy" => xy}} = Matcher.match("a [2=xy] c", "a X Y c")
    assert [%{raw: "X "}, %{raw: "Y "}] = xy
  end

  test "underscore" do
    assert {:match, _} = Matcher.match("hello _ world", "hello world")
    assert {:match, _} = Matcher.match("hello _ world", "hello good world")
    assert {:match, _} = Matcher.match("hello _ world", "hello really really really great world")

    assert :nomatch =
             Matcher.match(
               "hello _ world",
               "hello really really really great awesome blabla world"
             )
  end

  test "greedy vs. non-greedy" do
    # greedy is the default
    assert {:match, %{"a" => [_, _, _]}} = Matcher.match("[0-10=a]", "a a a")

    # nongreediness is specified with ? modifier after range
    assert {:match, %{"a" => []}} = Matcher.match("[0-10?=a]", "a a a")
    assert {:match, %{"a" => [_]}} = Matcher.match("[1-10?=a]", "a a a")
    assert {:match, %{"a" => [_]}} = Matcher.match("[1+?=a]", "a a a")
  end

  test "optional" do
    assert {:match, %{}} = Matcher.match("a b?", "a b c")
    assert {:match, %{}} = Matcher.match("a b?", "a c")
    assert {:match, %{}} = Matcher.match("a b?", "a b")
    assert {:match, %{}} = Matcher.match("a b?", "a")
  end

  test "[0-N]" do
    assert {:match, %{}} = Matcher.match("hello [0-1] world", "Hello, world!")
    assert {:match, %{}} = Matcher.match("hello [0-1] world", "Hello there world!")
    assert {:match, %{}} = Matcher.match("hello [0-2] world", "Hello you there world!")

    assert {:match, %{"x" => x}} = Matcher.match("hello [0-2=x] world", "Hello you world!")
    assert [%{raw: "you "}] = x

    assert {:match, %{"xy" => xy}} = Matcher.match("a [0-2=xy] c", "a X Y c")
    assert [%{raw: "X "}, %{raw: "Y "}] = xy
  end

  test "[N-M]" do
    assert :nomatch = Matcher.match("hello [1-1] world", "Hello world!")
    assert {:match, %{}} = Matcher.match("hello [1-1] world", "Hello there world!")
    assert {:match, %{}} = Matcher.match("hello [1-2] world", "Hello there you world!")
    assert {:match, %{}} = Matcher.match("hello [2-2] world", "Hello there you world!")
    assert :nomatch = Matcher.match("hello [2-2] world", "Hello there world!")
    assert :nomatch = Matcher.match("hello [2-3] world", "Hello there world!")

    assert :nomatch = Matcher.match("hello [10+] world", "Hello there world!")
    # assert {:match, %{"all" => all}} = Matcher.match("hello [1-=all]", "Hello a b c d!")
    # # non-greedy
    # assert 1 == length(all)

    assert :nomatch = Matcher.match("hello [10+]", "Hello a b c d!")
  end

  test "[N+]" do
    assert {:match, %{}} = Matcher.match("[1+] world", "hello world")
  end

  test "entities" do
    amsterdam = %Token{type: :entity, start: 10, end: 19, value: %{kind: "loc"}}

    sentence =
      Sentence.naive_tokenize("I live in Amsterdam")
      |> Sentence.add_tokenization([[amsterdam]])

    assert {:match, %{}} = Matcher.match("live in [loc]", sentence)
  end

  test "repetitions" do
    assert {:match, %{"m" => [_]}} = Matcher.match("a[1=m]", "a a")

    assert {:match, %{"m" => [_, _]}} = Matcher.match("a[2=m]", "a a")
    assert {:match, %{"m" => [_, _]}} = Matcher.match("a[2=m]", "a a a")
    assert :nomatch = Matcher.match("a[2=m]", "a")
    assert :nomatch = Matcher.match("a[4]", "a a a")
    assert :nomatch = Matcher.match("a[4]", "a a a")

    assert {:match, %{"a" => [_]}} = Matcher.match("a[1-3=a]", "a")
    assert {:match, %{"a" => [_, _]}} = Matcher.match("a[1-3=a]", "a a")
    assert {:match, %{"a" => [_, _, _]}} = Matcher.match("a[1-3=a]", "a a a")

    assert {:match, %{"a" => [_, _, _]}} = Matcher.match("a[1+=a]", "a a a")
    assert :nomatch = Matcher.match("a[4+=a]", "a a a")

    assert {:match, %{"x" => [_, _, _]}} = Matcher.match("(a | b | c)[2-3=x]", "c x a b a")
  end

  test "concepts" do
    assert {:match, _} = Matcher.match(compile("@flower"), "tulip")
    assert :nomatch = Matcher.match(compile("@flower"), "poopoo")

    # implicit assign
    assert {:match, %{"flower" => [_]}} = Matcher.match(compile("like @flower"), "I like Tulips")
  end

  test "punctuation is optional; alternative tokenization is added" do
    assert {:match, %{}} == Matcher.match("hello world [End]", "Hello world!")
    assert {:match, %{}} == Matcher.match("hello world", "Hello, world!")
    assert {:match, %{}} == Matcher.match("hello world", "Hello, *@#($)@ world!")

    assert :nomatch == Matcher.match("hello world", "hello asdf world")
  end

  test "accents are ignored" do
    assert {:match, %{}} == Matcher.match("hello world", "héllo wøŕĺḑ")

    assert {:match, %{}} == Matcher.match("héllo", "hellø")
  end

  ###

  defp compile(expr) do
    BubbleMatch.Parser.parse!(expr, concepts_compiler: &compile_concept/1)
  end

  defp compile_concept(a) do
    {:ok, {__MODULE__, :test_concept, [a]}}
  end

  @concepts %{
    "flower" => ["tulip", "rose", "tulips"],
    "transport" => ~w(train car bus bike metro airplane)
  }

  def test_concept(a, {collection}) do
    Enum.member?(@concepts[collection], a.value)
  end
end
