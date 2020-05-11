defmodule BubbleExpr.Parser do
  import NimbleParsec

  defmodule ParseError do
    defexception message: "Parse error"
  end

  @ws [9, 10, 11, 12, 13, 32]
  ws = ignore(ascii_char(@ws) |> concat(repeat(ascii_char(@ws))))

  string = ascii_string(Enum.to_list(?A..?Z) ++ Enum.to_list(?a..?z), min: 1)

  identifier = ascii_string(Enum.to_list(?A..?Z) ++ Enum.to_list(?a..?z), min: 1)

  defp to_int(a) do
    :string.to_integer(a) |> elem(0)
  end

  int = times(ascii_char([?0..?9]), min: 1) |> reduce(:to_int)

  literal =
    ignore(string("\""))
    |> repeat(utf8_char([{:not, ?"}]))
    |> reduce(:to_string)
    |> ignore(string("\""))
    |> unwrap_and_tag(:literal)

  word =
    string
    |> reduce(:finalize_word)

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
    {:eat, {n, override || n, :greedy}}
  end

  defp eat([a, "+", "?"], _override) do
    {:eat, {a, :infinity, :nongreedy}}
  end

  defp eat([a, "+"], _override) do
    {:eat, {a, :infinity, :greedy}}
  end

  defp eat([a, b], _override) do
    {:eat, {a, b, :greedy}}
  end

  defp eat([a, b, "?"], _override) do
    {:eat, {a, b, :nongreedy}}
  end

  defp concept(a) do
    {:concept, to_string(a) |> String.split(".") |> List.to_tuple()}
  end

  # slot assignment
  concept =
    ignore(string("@"))
    |> concat(string)
    |> optional(repeat(string(".") |> concat(string)))
    |> reduce(:concept)

  # slot assignment
  assign =
    ignore(string("="))
    |> concat(string)
    |> unwrap_and_tag(:assign)

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
      |> optional(string("?"))
      |> reduce(:eat),
      # start of sentence
      symbol.("Start", :start),
      # end of sentence
      symbol.("End", :end),
      string |> tag(:entity),
      empty()
    ])
    |> optional(assign)
    |> ignore(string("]"))

  defp finalize_word([str]) do
    {:word, String.downcase(str)}
  end

  defp finalize_rule([a, b, {:assign, v}]) do
    {a, b, c} = finalize_rule([a, b])
    {a, b, Keyword.put(c, :assign, v)}
  end

  defp finalize_rule([{:any, []}, {:entity, [type]}]) do
    {:entity, type, []}
  end

  defp finalize_rule([{:any, []}, :start]) do
    {:sentence_start, [], []}
  end

  defp finalize_rule([{:any, []}, :end]) do
    {:sentence_end, [], []}
  end

  defp finalize_rule([{:underscore, _}]) do
    {:any, [], [repeat: {0, 5, :greedy}]}
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

  pos =
    ignore(string("%"))
    |> concat(identifier)
    |> unwrap_and_tag(:pos)

  defcombinatorp(
    :rule,
    choice([
      word,
      regex,
      pos,
      literal,
      or_group,
      perm_group,
      concept,
      string("_") |> tag(:underscore),
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

  def parse!(input, opts \\ []) do
    case parse(input, opts) do
      {:ok, expr} -> expr
      {:error, message} -> raise ParseError, message
    end
  end

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
                    |> ensure_eat_before_rules()
                    |> compile_concepts(opts[:concepts_compiler])
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

          e in ParseError ->
            {:error, Exception.message(e)}
        end
    end
  end

  defp ensure_eat_before_rules([{:sentence_start, _, _} | _] = rules) do
    rules
  end

  defp ensure_eat_before_rules(rules) do
    [{:any, [], [repeat: {0, :infinity, :nongreedy}]} | rules]
  end

  defp walk_rules(rules, processor) do
    Enum.map(
      rules,
      fn node ->
        {verb, rules, meta} = processor.(node)

        if is_list(rules) do
          rules = Enum.map(rules, &walk_rules(&1, processor))
          {verb, rules, meta}
        else
          {verb, rules, meta}
        end
      end
    )
  end

  defp compile_concepts(rules, compiler) do
    walk_rules(rules, fn
      {:concept, ast, meta} ->
        case compiler do
          nil ->
            raise ParseError, "Missing concepts_compiler option"

          _ ->
            case compiler.(ast) do
              {:ok, result} ->
                {:concept, result, meta}

              {:error, message} ->
                raise ParseError, message

              other ->
                raise ParseError, "concepts_compiler returned invalid data: " <> inspect(other)
            end
        end

      x ->
        x
    end)
  end

  defp expand_permutations(rules) do
    walk_rules(rules, fn
      {:perm, rules, meta} ->
        {:or, permutations(rules), meta}

      x ->
        x
    end)
  end

  defp permutations([]), do: [[]]

  defp permutations(list),
    do: for(elem <- list, rest <- permutations(list -- [elem]), do: [elem | rest])

  defp add_implicit_assign(rules) do
    Enum.map(
      rules,
      fn
        {:entity, kind, meta} ->
          {:entity, kind, Keyword.put(meta, :assign, meta[:assign] || String.downcase(kind))}

        {:concept, {kind}, meta} ->
          {:concept, {kind}, Keyword.put(meta, :assign, meta[:assign] || String.downcase(kind))}

        {verb, rules, meta} when is_list(rules) ->
          {verb, Enum.map(rules, &add_implicit_assign/1), meta}

        x ->
          x
      end
    )
  end
end
