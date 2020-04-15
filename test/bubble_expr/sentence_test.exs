defmodule BubbleExpr.SentenceTest do
  use ExUnit.Case

  alias BubbleExpr.Sentence
  alias BubbleExpr.Token

  test "tokenize" do
    sentence = Sentence.naive_tokenize("Hello, world!")

    assert [
             %Token{raw: "Hello,", start: 0, end: 6, value: "hello"},
             %Token{raw: "world!", start: 7, end: 13, value: "world"}
           ] = sentence.tokens
  end
end
