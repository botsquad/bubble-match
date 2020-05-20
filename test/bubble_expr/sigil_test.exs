defmodule BubbleExpr.SigilTest do
  use ExUnit.Case

  use BubbleExpr.Sigil

  test "sigil" do
    assert {:match, _} = BubbleExpr.match(~m/hello | hi/, "hi there")
    assert :nomatch = BubbleExpr.match(~m/hello | hi/, "hullo")
  end

  @match ~m/dd/

  test "sigil in attr" do
    assert %BubbleExpr{} = @match
    assert :nomatch = BubbleExpr.match(@match, "hullo")
  end
end
