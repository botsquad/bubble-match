defmodule BubbleMatch.EntityTest do
  use ExUnit.Case

  alias BubbleMatch.Entity

  test "to_string" do
    e = Entity.new("custom", "person", "Mariah", "mariah")

    assert "person" == e.kind
    assert "custom" == e.provider
    assert "Mariah" == e.value
    assert "mariah" == e.raw

    assert "Mariah" == to_string(e)
  end

  test "to_string with custom entity value" do
    e = Entity.new("custom", "person", 123, 123, %{"foo" => 4123})

    assert "123" == to_string(e)
  end

  test "json" do
    e = Entity.new("custom", "person", "Mariah", "mariah")
    assert "{\"__struct__\":" <> _ = Jason.encode!(e)
  end
end
