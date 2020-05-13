defmodule BubbleExpr.Sentence.TokenizerTest do
  use ExUnit.Case

  alias BubbleExpr.Sentence.Tokenizer

  test "tokenize" do
    assert [hello, comma, _, _] = Tokenizer.tokenize("Hello, world.")

    assert %{value: "hello", raw: "Hello", start: 0, end: 5} = hello
    assert %{value: ",", raw: ", ", start: 5, end: 6} = comma
  end

  test "unicode" do
    assert [_] = Tokenizer.tokenize("📝")
  end

  test "compound" do
    assert [_] = Tokenizer.tokenize("a-b-c")
  end
end
