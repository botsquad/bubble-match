defmodule BubbleExpr.Parser do
  import NimbleParsec

  # ws       := [ ]+
  # word     := (A-Za-z)+
  # or_group := '(' ws? rule_seq (ws '|' ws rule_seq)* ws? ')'
  # perm_group := '<' ws? rule_seq ws? '>'

  # rule     := word | or_group
  # rule_seq := rule | rule ws rule_seq

  @ws [9, 10, 11, 12, 13, 32]
  ws = ignore(ascii_char(@ws) |> concat(repeat(ascii_char(@ws))))

  @string ascii_string(Enum.to_list(?A..?Z) ++ Enum.to_list(?a..?z), min: 1)

  literal =
    ignore(string("\""))
    |> repeat(utf8_char([{:not, ?"}]))
    |> reduce(:to_string)
    |> ignore(string("\""))
    |> unwrap_and_tag(:literal)

  word =
    @string
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

  perm_group =
    ignore(string("<"))
    |> optional(ws)
    |> parsec(:rule_seq)
    |> optional(ws)
    |> ignore(string(">"))
    |> unwrap_and_tag(:perm)

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

  defp eat([a, "+"], _override) do
    {:eat, {a, :infinity}}
  end

  defp eat([a, b], _override) do
    {:eat, {a, b}}
  end

  # slot assignment
  assign =
    ignore(string("="))
    |> concat(@string)
    |> unwrap_and_tag(:assign)

  defp to_int(a) do
    :string.to_integer(a) |> elem(0)
  end

  int = times(ascii_char([?0..?9]), min: 1) |> reduce(:to_int)

  control_block =
    ignore(string("["))
    |> choice([
      int
      |> optional(
        choice([
          string("+"),
          ignore(string("-")) |> concat(int)
        ])
      )
      |> reduce(:eat),
      # start of sentence
      symbol.("Start", :start),
      # end of sentence
      symbol.("End", :end),
      @string |> tag(:entity),
      empty()
    ])
    |> optional(assign)
    |> ignore(string("]"))

  defp finalize_rule([a, b, {:assign, v}]) do
    {a, b, c} = finalize_rule([a, b])
    {a, b, Keyword.put(c, :assign, v)}
  end

  defp finalize_rule([{:any, []}, {:entity, [type]}]) do
    {:entity, type, []}
  end

  defp finalize_rule([{:any, []}, value]) do
    {:any, value, []}
  end

  defp finalize_rule([{type, value}]) do
    {type, value, []}
  end

  defp finalize_rule([{type, value}, {:optional, []}]) do
    {:or, [[{type, value, []}], []], []}
  end

  defp finalize_rule([{type, value}, {:assign, _} = kv]) do
    {type, value, [kv]}
  end

  defp finalize_rule([{type, value}, {:eat, range}]) do
    {type, value, [repeat: range]}
  end

  defcombinatorp(
    :rule,
    choice([
      word,
      regex,
      literal,
      or_group,
      perm_group,
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
  def parse(input, opts \\ []) do
    case String.trim(input) do
      "" ->
        {:ok, %BubbleExpr{}}

      input ->
        try do
          case rule_seq(input) do
            {:ok, [parsed], "", _, _, _} ->
              parsed =
                case opts[:expand] do
                  false ->
                    parsed

                  _ ->
                    parsed
                    |> expand_permutations()
                    |> add_implicit_assign()
                    |> ensure_eat_before_rules(nil)
                end

              {:ok, %BubbleExpr{ast: parsed}}

            {:ok, _parsed, remain, _, _, _} ->
              {:error, "Parse error near \"#{remain}\""}

            {:error, _, remain, _, _, _} ->
              {:error, "Parse error near \"#{remain}\""}
          end
        rescue
          e in Regex.CompileError ->
            {:error, "Regex: " <> Exception.message(e)}
        end
    end
  end

  defp ensure_eat_before_rules(rules, prev) do
    Enum.reduce(rules, {prev, []}, fn rule, {last_rule_type, new_rules} ->
      {type, data, ctl} = rule

      if type != :any and last_rule_type != :any do
        data = ensure_eat_before_rules_inner(data)
        {type, [{type, data, ctl}, {:any, {:eat, {0, :infinity}}, []} | new_rules]}
      else
        {type, [rule | new_rules]}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  defp ensure_eat_before_rules_inner(list_of_rules) when is_list(list_of_rules) do
    list_of_rules |> Enum.map(&ensure_eat_before_rules(&1, :any))
  end

  defp ensure_eat_before_rules_inner(data), do: data

  defp expand_permutations(rules) do
    Enum.map(
      rules,
      fn
        {:perm, rules, meta} ->
          {:or, permutations(expand_permutations(rules)), meta}

        {verb, rules, meta} when is_list(rules) ->
          {verb, expand_permutations(rules), meta}

        x ->
          x
      end
    )
  end

  defp permutations([]), do: [[]]

  defp permutations(list),
    do: for(elem <- list, rest <- permutations(list -- [elem]), do: [elem | rest])

  defp add_implicit_assign(rules) do
    Enum.map(
      rules,
      fn
        {:entity, kind, meta} = triple ->
          case meta[:assign] do
            nil ->
              {:entity, kind, [{:assign, String.downcase(kind)} | meta]}

            _ ->
              triple
          end

        {verb, rules, meta} when is_list(rules) ->
          {verb, Enum.map(rules, &add_implicit_assign/1), meta}

        x ->
          x
      end
    )
  end
end
