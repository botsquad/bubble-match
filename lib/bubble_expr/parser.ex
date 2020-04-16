defmodule BubbleExpr.Parser do
  import NimbleParsec

  alias BubbleExpr.Validator

  # ws       := [ ]+
  # word     := (A-Za-z)+
  # or_group := '(' ws? rule_seq (ws '|' ws rule_seq)* ws? ')'

  # rule     := word | or_group
  # rule_seq := rule | rule ws rule_seq

  @ws [9, 10, 11, 12, 13, 32]
  ws = ignore(ascii_char(@ws) |> concat(repeat(ascii_char(@ws))))

  @az ascii_char(Enum.to_list(?A..?Z) ++ Enum.to_list(?a..?z))

  string_literal =
    ignore(string("\""))
    |> repeat(utf8_char([{:not, ?"}]))
    |> reduce(:to_string)
    |> ignore(string("\""))
    |> unwrap_and_tag(:string_literal)

  word =
    @az
    |> concat(repeat(@az))
    |> reduce(:to_string)
    |> unwrap_and_tag(:word)

  or_group =
    ignore(string("("))
    |> optional(ws)
    |> parsec(:rule_seq)
    |> optional(
      repeat(
        ws
        |> ignore(string("|"))
        |> concat(ws)
        |> parsec(:rule_seq)
      )
    )
    |> optional(ws)
    |> ignore(string(")"))
    |> tag(:or)

  defp regex_compile([regex]) do
    Regex.compile!(regex)
  end

  regex =
    ignore(string("/"))
    |> ascii_string([{:not, ?/}], min: 0)
    |> ignore(string("/"))
    |> reduce(:regex_compile)
    |> unwrap_and_tag(:regex)

  defp to_symbol([{s, []}]), do: s

  symbol = fn string, symbol ->
    ignore(string(string)) |> tag(symbol) |> reduce(:to_symbol)
  end

  defp eat(args, override \\ nil)

  defp eat([n], override) do
    {:eat, {n, override || n}}
  end

  defp eat([a, b], _override) do
    {:eat, {a, b}}
  end

  defcombinatorp(
    :control_code,
    choice([
      # start of sentence
      symbol.("Start", :start),
      # end of sentence
      symbol.("End", :end),
      # slot assignment
      ignore(string("="))
      |> concat(@az)
      |> repeat(@az)
      |> reduce(:to_string)
      |> unwrap_and_tag(:assign),
      # eat a range of tokens
      integer(min: 0)
      |> ignore(string("-"))
      |> optional(integer(min: 1))
      |> reduce({:eat, [:infinity]}),
      # eat a single token
      integer(min: 1)
      |> reduce(:eat),
      empty()
    ])
  )

  control_block =
    ignore(string("["))
    |> optional(ws)
    |> parsec(:control_code)
    |> repeat(ignore(string(";")) |> parsec(:control_code))
    |> optional(ws)
    |> ignore(string("]"))
    |> tag(:control_block)

  defp finalize_rule([{type, value}]) do
    {type, value, []}
  end

  defp finalize_rule([{type, value}, {:optional, []}]) do
    {type, value, [optional: true]}
  end

  defp finalize_rule([{type, value}, {:control_block, block}]) do
    {type, value, block}
  end

  defcombinatorp(
    :rule,
    choice([
      word,
      regex,
      string_literal,
      or_group,
      lookahead(string("[")) |> tag(:any)
    ])
    |> optional(choice([control_block, ignore(string("?")) |> tag(:optional)]))
    |> reduce(:finalize_rule)
  )

  defp finalize_seq(r) do
    r
  end

  defparsecp(
    :rule_seq,
    parsec(:rule)
    |> repeat(ws |> concat(parsec(:rule)))
    |> reduce(:finalize_seq)
  )

  # defparsec(:parse, parsec(:rule_seq))
  def parse(input) do
    case rule_seq(input) do
      {:ok, [parsed], "", _, _, _} ->
        # Validator.validate(parsed)
        parsed = ensure_eat_before_rules(parsed, nil)

        {:ok, %BubbleExpr{ast: parsed}}

      {:ok, _parsed, remain, _, _, _} ->
        {:error, "Parse error near \"#{remain}\""}
    end
  end

  defp ensure_eat_before_rules(rules, prev) do
    Enum.reduce(rules, {prev, []}, fn rule, {last_rule_type, new_rules} ->
      {type, data, ctl} = rule

      if type != :any and last_rule_type != :any do
        data = ensure_eat_before_rules_inner(data)
        {type, [{type, data, ctl}, {:any, [], [eat: {0, :infinity}]} | new_rules]}
      else
        {type, [rule | new_rules]}
      end
    end)
    |> elem(1)
    |> Enum.reverse()

    #    |> IO.inspect(label: "x")
  end

  defp ensure_eat_before_rules_inner(list_of_rules) when is_list(list_of_rules) do
    list_of_rules |> Enum.map(&ensure_eat_before_rules(&1, :any))
  end

  defp ensure_eat_before_rules_inner(data), do: data
end
