defmodule BubbleExpr.Matcher do
  alias BubbleExpr.{Parser, Sentence}

  def match(expr, input) when is_binary(expr) do
    with {:ok, expr} <- Parser.parse(expr) do
      match(expr, input)
    end
  end

  def match(expr, input) when is_binary(input) do
    sentence = Sentence.naive_tokenize(input)
    match(expr, sentence)
  end

  def match(%BubbleExpr{} = expr, %Sentence{} = sentence) do
    [seq] = expr.ast
    match_seq(seq, sentence.tokens, %{})
  end

  defp match_seq({:seq, rules}, tokens, context) do
    match_rules(rules, tokens, context)
  end

  defp match_rules([], _, context) do
    {:match, context}
  end

  defp match_rules(_, [], _context) do
    :nomatch
  end

  defp match_rules([{:rule, [{type, _} | _] = rule} | _] = rules, [token | _] = tokens, context) do
    case type do
      :word ->
        case token.value == rule[:word] do
          true ->
            match_rules(tl(rules), tl(tokens), context)

          false ->
            match_rules(rules, tl(tokens), context)
        end

      :or_group ->
        rule[:or_group]
        |> Enum.reduce(:nomatch, fn
          seq, :nomatch ->
            match_seq(seq, tokens, context)

          _, result ->
            result
        end)

      _ ->
        :nomatch
    end
  end
end
