defmodule BubbleExpr.SentenceTest do
  use ExUnit.Case

  alias BubbleExpr.Sentence
  alias BubbleExpr.Token

  @tag skip: true
  test "add_tokenization" do
    sentence = Sentence.naive_tokenize("Hello, world!")
    new_tokens = [%Token{index: 0, raw: "Hello,", start: 0, end: 6, value: "hullo"}]
    sentence = Sentence.add_tokenization(sentence, new_tokens)

    assert [
             [
               %Token{index: 0, raw: "Hello,", start: 0, end: 6, value: "hullo"},
               %Token{index: 1, raw: "world!", start: 7, end: 13, value: "world"}
             ],
             [_, _]
           ] = sentence.tokenizations

    # sentence = Sentence.naive_tokenize("Hello, world!")
    # new_tokens = [%Token{index: 0, raw: "Hello, world!", start: 0, end: 6, value: "yo"}]
    # sentence = Sentence.add_tokenization(sentence, 0, 2, new_tokens)
    # assert [%{value: "yo"}] = sentence.tokens
  end
end
