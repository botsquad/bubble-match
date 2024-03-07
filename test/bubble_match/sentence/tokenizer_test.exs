defmodule BubbleMatch.Sentence.TokenizerTest do
  use ExUnit.Case

  alias BubbleMatch.Sentence.Tokenizer

  test "tokenize" do
    assert [hello, comma, _, _] = Tokenizer.tokenize("Hello, world.")

    assert %{value: "hello", raw: "Hello", start: 0, end: 5} = hello
    assert %{value: ",", raw: ", ", start: 5, end: 6} = comma
  end

  test "tokenize accents" do
    assert [a, b, c] = Tokenizer.tokenize("Harry's burgers")

    assert %{raw: "Harry"} = a
    assert %{raw: "'s ", value: "'s"} = b
    assert %{raw: "burgers"} = c
  end

  test "unicode" do
    assert [_] = Tokenizer.tokenize("📝")
  end

  test "compound" do
    assert [_] = Tokenizer.tokenize("a-b-c")
  end

  test "whitespace" do
    assert [_, _] = Tokenizer.tokenize("\nHello world\n   \n")
    assert [_, _] = Tokenizer.tokenize("	Hello world")
    assert [_, _] = Tokenizer.tokenize(" Hello world")
    assert [_, _] = Tokenizer.tokenize(" Hello world   ")
    assert [] = Tokenizer.tokenize("   ")
    assert [] = Tokenizer.tokenize("")
  end

  test "other languages" do
    # polish
    assert [_, _] = Tokenizer.tokenize("dzień dobry")
    # arabic
    assert [_, _] = Tokenizer.tokenize("صباح الخير")
    # ukrainan
    assert [_, _] = Tokenizer.tokenize("Добрий ранок")
  end
end
