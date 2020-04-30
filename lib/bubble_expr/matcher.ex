defmodule BubbleExpr.Matcher do
  alias BubbleExpr.{Parser, Sentence, Token}

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
    Enum.reduce_while(sentence.tokenizations, :nomatch, fn tokens, acc ->
      case match_rules(expr.ast, tokens, [], %{}) do
        {:match, _, _, context} ->
          {:halt, {:match, context}}

        :nomatch ->
          {:cont, acc}
      end
    end)
  end

  defp match_rules([], ts_remaining, ts_match, context) do
    {:match, ts_remaining, ts_match, context}
  end

  defp match_rules([{:any, t, []} | _], [], ts_match, context) when t in ~w(start end)a do
    {:match, [], ts_match, context}
  end

  defp match_rules(_, [], _ts_match, _context) do
    :nomatch
  end

  defp match_rules([{_, _, ctl} = rule | rest], ts_remaining, ts_match, context) do
    repeat = ctl[:repeat] || {1, 1}

    with {:match, ts_remaining, inner, context} <-
           match_rule_repeat(repeat, rule, rest, ts_remaining, [], context) do
      context = opt_assign(ctl, inner, context)
      match_rules(rest, ts_remaining, inner ++ ts_match, context)
    end
  end

  defp match_rule_repeat({1, 1}, rule, rls_remaining, ts_remaining, ts_match, context) do
    with {:match, ts_remaining, inner, context} <-
           match_rule(rule, rls_remaining, ts_remaining, context) do
      {:match, ts_remaining, inner ++ ts_match, context}
    end
  end

  defp match_rule_repeat({n, n}, rule, rls_remaining, ts_remaining, ts_match, context)
       when n > 1 do
    with {:match, ts_remaining, inner, context} <-
           match_rule(rule, rls_remaining, ts_remaining, context) do
      match_rule_repeat(
        {n - 1, n - 1},
        rule,
        rls_remaining,
        ts_remaining,
        inner ++ ts_match,
        context
      )
    end
  end

  defp match_rule_repeat({n, m}, rule, rls_remaining, ts_remaining, ts_match, context)
       when m > n do
    m = prevent_infinity(m, n, ts_remaining)

    with :nomatch <-
           match_rule_repeat({m, m}, rule, rls_remaining, ts_remaining, ts_match, context) do
      match_rule_repeat({n, m - 1}, rule, rls_remaining, ts_remaining, ts_match, context)
    end
  end

  defp match_rule({:word, word, _}, _rls_remaining, ts_remaining, context) do
    fn t -> Token.word?(t, word) end
    |> boolean_match(ts_remaining, context)
  end

  defp match_rule({:entity, e, _}, _rls_remaining, ts_remaining, context) do
    fn t -> Token.entity?(t, e) end
    |> boolean_match(ts_remaining, context)
  end

  defp match_rule({:regex, re, _}, _rls_remaining, ts_remaining, context) do
    fn t -> Token.regex?(t, re) end
    |> boolean_match(ts_remaining, context)
  end

  defp match_rule({:or, seqs, _}, _rls_remaining, ts_remaining, context) do
    with {:match, ts_remaining, inner, context} <-
           match_any_list_of_rules(seqs, ts_remaining, [], context) do
      {:match, ts_remaining, inner, context}
    end
  end

  defp match_rule({:any, {:eat, range}, _}, rls_remaining, ts_remaining, context) do
    with {eaten, ts_remaining} <- match_eat_tokens(range, rls_remaining, ts_remaining, []) do
      {:match, ts_remaining, eaten, context}
    end
  end

  defp match_rule({:literal, str, _}, _rls_remaining, [t | _] = ts_remaining, context) do
    offset = t.start

    ts_remaining
    |> Enum.reduce_while(
      {[], ts_remaining},
      fn t, {matched, remaining} = acc ->
        {_, chunk} = String.split_at(str, t.start - offset)

        cond do
          t.start - offset > String.length(str) ->
            {:halt, acc}

          String.starts_with?(chunk, t.raw) ->
            {:cont, {[t | matched], tl(remaining)}}

          String.length(chunk) < String.length(t.raw) and String.starts_with?(t.raw, chunk) ->
            {:cont, {[t | matched], tl(remaining)}}

          true ->
            {:halt, acc}
        end
      end
    )
    |> case do
      {[], _} ->
        :nomatch

      {matched, remaining} ->
        {:match, remaining, matched, context}
    end
  end

  defp match_rule({:any, :start, _}, _rls_remaining, ts_remaining, context) do
    case ts_remaining do
      [%{index: 0} | _] ->
        {:match, ts_remaining, [], context}

      _ ->
        :nomatch
    end
  end

  defp match_rule({:any, :end, _}, _rls_remaining, _ts_remaining, _context) do
    :nomatch
  end

  ###

  defp match_eat_tokens(nil, _rules, ts_remaining, add) do
    {add, ts_remaining}
  end

  defp match_eat_tokens({n, _m}, _rules, ts_remaining, _add) when n > length(ts_remaining) do
    :nomatch
  end

  defp match_eat_tokens({n, n}, _rules, ts_remaining, add) do
    {left, right} = Enum.split(ts_remaining, n)
    {Enum.reverse(left) ++ add, right}
  end

  defp match_eat_tokens({n, m}, rules, ts_remaining, add) when n > 0 do
    {left, right} = Enum.split(ts_remaining, n)
    {Enum.reverse(left), right}
    m = prevent_infinity(m, n, ts_remaining)
    match_eat_tokens({0, m - n}, rules, right, add ++ Enum.reverse(left))
  end

  defp match_eat_tokens({0, n}, rules, ts_remaining, add) do
    n = prevent_infinity(n, 0, ts_remaining)

    # here we need to try the rules for the 0..n splits of ts_remaining.
    Enum.reduce(0..n, :nomatch, fn
      n, :nomatch ->
        {left, right} = Enum.split(ts_remaining, n)

        with {:match, _, _, _} <- match_rules(rules, right, [], %{}) do
          {add ++ Enum.reverse(left), right}
        end

      _n, result ->
        result
    end)
  end

  defp prevent_infinity(:infinity, n, tokens), do: n + length(tokens)
  defp prevent_infinity(m, _n, _tokens), do: m

  defp boolean_match(_test, [], _context) do
    :nomatch
  end

  defp boolean_match(test, [t | ts_remaining], context) do
    case test.(t) do
      true ->
        {:match, ts_remaining, [t], context}

      false ->
        :nomatch
    end
  end

  defp match_any_list_of_rules(list_of_rules, tokens, ts_match, context) do
    Enum.reduce(list_of_rules, :nomatch, fn
      rules, :nomatch ->
        match_rules(rules, tokens, ts_match, context)

      _, result ->
        result
    end)
  end

  defp opt_assign(ctl, tokens, context) do
    case ctl[:assign] do
      nil -> context
      key -> Map.put(context, key, Enum.reverse(tokens))
    end
  end
end
