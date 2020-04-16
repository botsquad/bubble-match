defmodule BubbleExpr.SentenceTest do
  use ExUnit.Case

  alias BubbleExpr.Sentence
  alias BubbleExpr.Token

  test "tokenize" do
    sentence = Sentence.naive_tokenize("Hello, world!")

    assert [
             %Token{index: 0, raw: "Hello,", start: 0, end: 6, value: "hello"},
             %Token{index: 1, raw: "world!", start: 7, end: 13, value: "world"}
           ] = sentence.tokens
  end
end
