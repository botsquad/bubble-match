defmodule BubbleExpr.MatcherTest do
  use ExUnit.Case

  alias BubbleExpr.Matcher

  test "matcher" do
    assert {:match, %{}} == Matcher.match("hello", "Hello, world!")
    assert {:match, %{}} == Matcher.match("world", "Hello, world!")
    assert {:match, %{}} == Matcher.match("hello world", "Hello, world!")

    assert :nomatch == Matcher.match("world hello", "Hello, world!")
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
end
