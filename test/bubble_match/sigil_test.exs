defmodule BubbleMatch.SigilTest do
  use ExUnit.Case

  use BubbleMatch.Sigil

  test "sigil" do
    assert {:match, _} = BubbleMatch.match(~m/hello | hi/, "hi there")
    assert :nomatch = BubbleMatch.match(~m/hello | hi/, "hullo")
  end

  @match ~m/dd/

  test "sigil in attr" do
    assert %BubbleMatch{} = @match
    assert :nomatch = BubbleMatch.match(@match, "hullo")
  end
end
