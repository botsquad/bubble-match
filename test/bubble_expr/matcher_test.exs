defmodule BubbleExpr.MatcherTest do
  use ExUnit.Case

  alias BubbleExpr.Matcher

  test "matcher" do
    assert {:match, %{}} == Matcher.match("hello", "Hello, world!")
    assert {:match, %{}} == Matcher.match("world", "Hello, world!")
    assert {:match, %{}} == Matcher.match("hello world", "Hello, world!")
    assert :nomatch == Matcher.match("world hello", "Hello, world!")
  end

  @tag skip: true
  test "literal" do
    assert {:match, %{}} == Matcher.match("\"world!\"", "Hello, world!")
    assert {:match, %{}} == Matcher.match("\"San Francisco\"", "I live in San Francisco, dude.")
  end

  test "regex" do
    assert {:match, %{}} == Matcher.match("/\\d+/", "foo 32432")
    assert :nomatch == Matcher.match("/[a-z][a-z]+/", "a")
    assert :nomatch == Matcher.match("/[a-z][a-z]+/", "ASDF")
  end

  test "regex with capturing" do
    assert {:match, %{"zip" => [t]}} = Matcher.match("/\\d+/[=zip]", "foo 1234 lala")
    assert "1234" == t.raw
  end

  test "OR group" do
    assert {:match, %{}} == Matcher.match("(hello | hi) world", "Hello world!")
    assert {:match, %{}} == Matcher.match("(hello | hi) (there | world)", "hi there!")
    assert :nomatch == Matcher.match("(hello | hi) you", "hello me")
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
    assert {:match, %{"greeting" => tokens}} = Matcher.match("hello[=greeting]", "Hello, world!")
    assert [%{raw: "Hello,"}] = tokens

    assert {:match, %{"greeting" => tokens}} =
             Matcher.match("(hello world)[=greeting]", "boohoo Hello, world! Bye")

    assert [%{raw: "Hello,"}, %{raw: "world!"}] = tokens

    assert {:match, %{"greeting" => greeting, "planet" => [planet]}} =
             Matcher.match(
               "(hello (world | earth)[=planet])[=greeting]",
               "boohoo Hello, world! Bye"
             )

    assert [%{raw: "Hello,"}, %{raw: "world!"}] = greeting
    assert %{raw: "world!"} = planet
  end

  test "[Start]" do
    assert {:match, %{}} = Matcher.match("[Start] hello", "Hello, world!")
    assert :nomatch = Matcher.match("[Start] hello", "Well hello there")
  end

  test "[End]" do
    assert {:match, %{}} = Matcher.match("world [End]", "Hello, world!")
    assert :nomatch = Matcher.match("world [End]", "The world is ending")
  end

  test "[Start] [End]" do
    assert {:match, %{}} = Matcher.match("[Start] [End]", "")
    assert :nomatch = Matcher.match("[Start] [End]", "lala")
  end

  test "[N]" do
    #    assert {:match, %{}} = Matcher.match("[1]", "hello")
    assert {:match, %{}} = Matcher.match("[0+] world", "hello world")
    assert {:match, %{}} = Matcher.match("[2]", "hello world")
    assert {:match, %{}} = Matcher.match("[2]", "hello world there")
    assert :nomatch = Matcher.match("[2]", "hello")
    assert :nomatch = Matcher.match("[100]", "a b c d e")

    assert {:match, %{}} = Matcher.match("hello [0] world", "Hello, world!")
    assert :nomatch = Matcher.match("hello [0] world", "Hello there, world!")

    assert {:match, %{}} = Matcher.match("a [1] c", "a b c")
    assert {:match, %{}} = Matcher.match("a [2] c", "a b b c")

    assert {:match, %{"xy" => xy}} = Matcher.match("a [2=xy] c", "a X Y c")
    assert [%{raw: "X"}, %{raw: "Y"}] = xy
  end

  test "[0-N]" do
    assert {:match, %{}} = Matcher.match("hello [0-1] world", "Hello, world!")
    assert {:match, %{}} = Matcher.match("hello [0-1] world", "Hello there, world!")
    assert {:match, %{}} = Matcher.match("hello [0-2] world", "Hello you there, world!")

    assert {:match, %{"x" => x}} = Matcher.match("hello [0-2=x] world", "Hello you, world!")
    assert [%{raw: "you,"}] = x

    assert {:match, %{"xy" => xy}} = Matcher.match("a [0-2=xy] c", "a X Y c")
    assert [%{raw: "X"}, %{raw: "Y"}] = xy
  end

  test "[N-M]" do
    assert :nomatch = Matcher.match("hello [1-1] world", "Hello, world!")
    assert {:match, %{}} = Matcher.match("hello [1-1] world", "Hello there, world!")
    assert {:match, %{}} = Matcher.match("hello [1-2] world", "Hello there, you world!")
    assert {:match, %{}} = Matcher.match("hello [2-2] world", "Hello there, you world!")
    assert :nomatch = Matcher.match("hello [2-2] world", "Hello there world!")
    assert :nomatch = Matcher.match("hello [2-3] world", "Hello there world!")

    assert :nomatch = Matcher.match("hello [10+] world", "Hello there world!")
    # assert {:match, %{"all" => all}} = Matcher.match("hello [1-=all]", "Hello a b c d!")
    # # non-greedy
    # assert 1 == length(all)

    assert :nomatch = Matcher.match("hello [10+]", "Hello a b c d!")
  end
end
