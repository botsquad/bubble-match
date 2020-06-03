defmodule BubbleMatch.Parser do
  @moduledoc false

  import NimbleParsec

  alias BubbleMatch.ParseError

  @ws [9, 10, 11, 12, 13, 32]
  ws = ignore(utf8_string(@ws, min: 1))

  special_chars = '`~!@#$%^&*()_+=-{}|\\][\';":?><,./' ++ @ws

  string = utf8_string(Enum.map(special_chars, &{:not, &1}), min: 1)

  identifier = utf8_string([?_] ++ Enum.to_list(?A..?Z) ++ Enum.to_list(?a..?z), min: 1)

  defp to_int(a) do
    :string.to_integer(a) |> elem(0)
  end

  int = times(utf8_char([?0..?9]), min: 1) |> reduce(:to_int)

  defp finalize_literal([word]) do
    {:literal, String.downcase(word)}
  end

  literal = fn char ->
    ignore(utf8_char([char]))
    |> repeat(utf8_char([{:not, char}]))
    |> reduce(:to_string)
    |> ignore(utf8_char([char]))
    |> reduce(:finalize_literal)
  end

  word =
    string
    |> optional(ignore(string("-")) |> concat(string))
    |> reduce(:finalize_word)

  or_group =
    ignore(string("("))
    |> optional(ws)
    |> parsec(:rules_seq)
    |> optional(ws)
    |> ignore(string(")"))

  perm_group =
    ignore(string("<"))
    |> optional(ws)
    |> parsec(:rule_seq)
    |> optional(ws)
    |> ignore(string(">"))
    |> unwrap_and_tag(:perm)

  defp regex_compile(r) do
    Regex.compile!(to_string(r), "iu")
  end

  regex =
    ignore(ascii_char([?/]))
    |> repeat(
      lookahead_not(ascii_char([?/]))
      |> choice([
        ~S(\/) |> string() |> replace(?/),
        utf8_char([])
      ])
    )
    |> ignore(ascii_char([?/]))
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
    |> concat(identifier)
    |> optional(repeat(string(".") |> concat(identifier)))
    |> reduce(:concept)

  # slot assignment
  assign =
    ignore(string("="))
    |> concat(identifier)
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
      identifier |> tag(:entity),
      empty()
    ])
    |> optional(assign)
    |> ignore(string("]"))

  defp finalize_word([str]) do
    word = String.downcase(str) |> Unidekode.to_ascii()
    {:word, word}
  end

  defp finalize_word([a, b]) do
    a = String.downcase(a)
    b = String.downcase(b)
    {:or, [[{:word, a <> b, []}], [{:word, a <> "-" <> b, []}], [{:word, a, []}, {:word, b, []}]]}
  end

  defp finalize_rule([a, b, {:assign, v}]) do
    {a, b, c} = finalize_rule([a, b])
    {a, b, Keyword.put(c, :assign, v)}
  end

  entitites_file = "#{__DIR__}/valid_entities.txt"
  @external_resource entitites_file
  @entities Application.get_env(:bubble_match, :valid_entities) ||
              File.read!(entitites_file) |> String.trim() |> String.split("\n")

  defp finalize_rule([{:any, []}, {:entity, [type]}]) when type in @entities do
    {:entity, type, []}
  end

  defp finalize_rule([{:any, []}, {:entity, [type]}]) do
    raise ParseError, "Invalid entity: " <> type
  end

  defp finalize_rule([_, {:entity, _}]) do
    raise ParseError, "Invalid entity declaration"
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

  defp finalize_rule([{type, value, meta}, {:eat, v}]) do
    {type, value, Keyword.put(meta, :repeat, v)}
  end

  defp finalize_rule([{type, value, meta}, {:assign, v}]) do
    {type, value, Keyword.put(meta, :assign, v)}
  end

  defp finalize_rule([{type, value}, {:optional, []}]) do
    {type, value, [repeat: {0, 1, :greedy}]}
  end

  defp finalize_rule([{type, value, meta}, {:optional, []}]) do
    {type, value, Keyword.put(meta, :repeat, {0, 1, :greedy})}
  end

  defp finalize_rule([{type, value}, {:assign, _} = kv]) do
    {type, value, [kv]}
  end

  defp finalize_rule([{_, _}, {:optional, _}, {:eat, _}]) do
    raise ParseError, "Cannot combine optional and repeat modifiers"
  end

  defp finalize_rule([{_, _}, {:optional, _}, {:entity, _}]) do
    raise ParseError, "Cannot combine optional before entity modifiers"
  end

  defp finalize_rule([{type, value}, {:eat, range}]) do
    {type, value, [repeat: range]}
  end

  defp finalize_rule([{a, b, c}]) do
    {a, b, c}
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
      literal.(?"),
      literal.(?'),
      or_group,
      perm_group,
      concept,
      string("_") |> tag(:underscore),
      lookahead(string("[")) |> tag(:any)
    ])
    |> optional(ignore(string("?")) |> tag(:optional))
    |> optional(control_block)
    |> reduce(:finalize_rule)
  )

  defp finalize_seq(r) do
    r
  end

  defp finalize_rules_seq(r) do
    {:or, r, []}
  end

  defparsecp(
    :rule_seq,
    parsec(:rule)
    |> repeat(ws |> concat(parsec(:rule)))
    |> reduce(:finalize_seq)
  )

  defparsecp(
    :rules_seq,
    parsec(:rule_seq)
    |> repeat(optional(ws) |> ignore(string("|")) |> optional(ws) |> parsec(:rule_seq))
    |> reduce(:finalize_rules_seq)
  )

  def parse!(input, opts \\ []) do
    case parse(input, opts) do
      {:ok, expr} -> expr
      {:error, message} -> raise ParseError, message
    end
  end

  def parse(input, opts \\ [])

  def parse(".*", opts), do: parse("[1+]", opts)
  def parse("^" <> _ = s, opts), do: parse("/#{s}/", opts)

  def parse(input, opts) do
    case String.trim(input) do
      "" ->
        {:ok, %BubbleMatch{}}

      input ->
        try do
          case rules_seq(input) do
            {:ok, parsed, "", _, _, _} ->
              parsed =
                case opts[:expand] do
                  false ->
                    parsed
                    |> reduce_ors()

                  _ ->
                    parsed
                    |> expand_permutations()
                    |> reduce_ors()
                    |> add_implicit_assign()
                    |> ensure_eat_before_rules()
                    |> compile_concepts(opts[:concepts_compiler])
                end

              {:ok, %BubbleMatch{ast: parsed, q: input}}

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

  defp reduce_ors(rules) do
    Enum.flat_map(
      rules,
      fn
        {:or, [[{a, b, c}]], meta} ->
          [{a, b, Keyword.merge(c, meta)}]

        {:or, [rules], []} ->
          rules

        {verb, rules, meta} when is_list(rules) ->
          [{verb, Enum.map(rules, &reduce_ors/1), meta}]

        x ->
          [x]
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
end
