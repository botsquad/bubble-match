defmodule BubbleExpr.MatcherTest do
  use ExUnit.Case

  alias BubbleExpr.Matcher

  test "matcher" do
    assert {:match, %{}} == Matcher.match("hello", "Hello, world!")
    assert {:match, %{}} == Matcher.match("world", "Hello, world!")
    assert {:match, %{}} == Matcher.match("hello world", "Hello, world!")
    assert :nomatch == Matcher.match("world hello", "Hello, world!")
    assert {:match, %{}} == Matcher.match("(hello | hi) world", "Hello world!")
    assert {:match, %{}} == Matcher.match("(hello | hi) (there | world)", "hi there!")
  end
end
