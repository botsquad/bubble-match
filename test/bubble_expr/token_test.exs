defmodule BubbleExpr.TokenTest do
  use ExUnit.Case

  test "string" do
    t = %BubbleExpr.Token{raw: "aap"}
    assert "aap" == to_string(t)
  end
end
