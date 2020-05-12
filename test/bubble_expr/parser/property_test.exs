defmodule BubbleExpr.Parser.PropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  alias BubbleExpr.Parser

  setup do
    Application.put_env(:stream_data, :max_runs, 100)
    :ok
  end

  def expr do
    list_of(
      one_of([
        string(:alphanumeric)
        | Enum.map('[]!@#*&^*#@*)()=-_+{}|\][\';:"/.,<>?] ', &constant/1)
      ])
    )
  end

  property "parse always returns a tuple" do
    check all expr <- expr() do
      expr = to_string(expr)
      assert {reason, _} = Parser.parse(expr)
      assert reason in [:ok, :error]
    end
  end
end
