defmodule BubbleExpr.Sentence.TokenizerTest do
  use ExUnit.Case

  alias BubbleExpr.Sentence.Tokenizer

  test "tokenize" do
    assert [hello, comma, _, _] = Tokenizer.tokenize("Hello, world.")

    assert %{value: "hello", raw: "Hello"} = hello
    assert %{value: ",", raw: ", "} = comma
  end
end
