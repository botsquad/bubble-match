defmodule BubbleMatchTest do
  use ExUnit.Case

  test "match" do
    assert {:match, %{}} == BubbleMatch.match("hello", "hello")
  end

  test "parse" do
    assert {:ok, %BubbleMatch{}} = BubbleMatch.parse("hello (there | world)")
    assert {:error, _} = BubbleMatch.parse("hello (")
  end

  test "parse!" do
    assert %BubbleMatch{} = BubbleMatch.parse!("hello (there | world)")
    assert_raise BubbleMatch.ParseError, fn -> BubbleMatch.parse!("hello (") end
  end

  test "can be inspected" do
    assert "#BML<>" == inspect(%BubbleMatch{})

    bml = BubbleMatch.parse!("hello world")
    assert "#BML<hello world>" == inspect(bml)
  end

  test "can be converted to string" do
    assert "" == to_string(%BubbleMatch{})

    bml = BubbleMatch.parse!("hello world")
    assert "hello world" == to_string(bml)
  end

  test "can encode to JSON" do
    assert "\"\"" == Jason.encode!(%BubbleMatch{})

    bml = BubbleMatch.parse!("hello world")
    assert "\"hello world\"" == Jason.encode!(bml)
  end
end
