defmodule BubbleMatch.Parser.PropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  alias BubbleMatch.Parser

  setup do
    max_runs =
      case System.get_env("CI") do
        nil -> 1000
        _ -> 10_000
      end

    Application.put_env(:stream_data, :max_runs, max_runs)

    :ok
  end

  @tokens ~w([ ] word [0-9] [1] [10] [1+] [1+?] =assign [=assign] 1+ 0-10 10-100? %postag @concept ~concept)c

  def expr do
    list_of(one_of([constant(32), one_of(Enum.map(@tokens, &constant/1))]), min_length: 1)
    |> map(&List.flatten/1)
    |> map(&mutate/1)
    |> map(&to_string/1)
  end

  property "parse always returns a tuple" do
    check all expr <- expr() do
      assert {reason, _} = Parser.parse(expr)
      assert reason in [:ok, :error]
    end
  end

  defp mutate(list) do
    ii = Enum.at(list, :rand.uniform(Enum.count(list)))
    list = List.delete(list, ii)
    jj = Enum.at(list, :rand.uniform(Enum.count(list)))
    List.delete(list, jj)
  end
end
