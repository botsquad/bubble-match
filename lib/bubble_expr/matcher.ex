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

    with {:match, context, _, _} <- match_seq(seq, sentence.tokens, [], %{}) do
      {:match, context}
    end
  end

  defp match_seq({:seq, rules}, ts_remaining, ts_match, context) do
    match_rules(rules, ts_remaining, ts_match, context)
  end

  defp match_rules([], ts_remaining, ts_match, context) do
    {:match, context, ts_remaining, ts_match}
  end

  defp match_rules(_, [], _ts_match, _context) do
    :nomatch
  end

  defp match_rules(
         [{:rule, [{type, _} | _] = rule} | _] = rules,
         [t | _] = ts_remaining,
         ts_match,
         context
       ) do
    case type do
      :word ->
        test = fn -> t.value == rule[:word] end
        boolean_match(t, test, rule, context, rules, ts_remaining, ts_match, context)

      :or_group ->
        with {:match, context, ts_remaining, inner} <-
               match_any_seq(rule[:or_group], ts_remaining, [], context) do
          context = opt_assign(rule, inner, context)
          match_rules(tl(rules), ts_remaining, inner ++ ts_match, context)
        end

      :regex ->
        test = fn -> Regex.match?(rule[:regex], t.raw) end
        boolean_match(t, test, rule, context, rules, ts_remaining, ts_match, context)

      _ ->
        :nomatch
    end
  end

  defp boolean_match(t, test, rule, context, rules, ts_remaining, ts_match, context) do
    case test.() do
      true ->
        context = opt_assign(rule, [t], context)
        match_rules(tl(rules), tl(ts_remaining), [t | ts_match], context)

      false ->
        match_rules(rules, tl(ts_remaining), ts_match, context)
    end
  end

  defp match_any_seq(seqs, tokens, ts_match, context) do
    Enum.reduce(seqs, :nomatch, fn
      seq, :nomatch ->
        match_seq(seq, tokens, ts_match, context)

      _, result ->
        result
    end)
  end

  defp opt_assign(rule, tokens, context) do
    case rule[:control_block][:assign] do
      nil -> context
      key -> Map.put(context, key, Enum.reverse(tokens))
    end
  end
end
