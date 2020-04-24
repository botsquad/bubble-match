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

  test "replace_tokens" do
    sentence = Sentence.naive_tokenize("Hello, world!")
    new_tokens = [%Token{index: 0, raw: "Hello,", start: 0, end: 6, value: "hullo"}]
    sentence = Sentence.replace_tokens(sentence, 0, 1, new_tokens)

    assert [
             %Token{index: 0, raw: "Hello,", start: 0, end: 6, value: "hullo"},
             %Token{index: 1, raw: "world!", start: 7, end: 13, value: "world"}
           ] = sentence.tokens

    sentence = Sentence.naive_tokenize("Hello, world!")
    new_tokens = [%Token{index: 0, raw: "Hello, world!", start: 0, end: 6, value: "yo"}]
    sentence = Sentence.replace_tokens(sentence, 0, 2, new_tokens)
    assert [%{value: "yo"}] = sentence.tokens
  end
end
