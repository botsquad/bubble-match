defmodule BubbleMatch.TokenTest do
  use ExUnit.Case

  test "string" do
    t = %BubbleMatch.Token{raw: "aap"}
    assert "aap" == to_string(t)
  end
end
