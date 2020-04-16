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
    with {:match, _, _, context} <- match_rules(expr.ast, sentence.tokens, [], %{}) do
      {:match, context}
    end
  end

  defp match_rules([], ts_remaining, ts_match, context) do
    {:match, ts_remaining, ts_match, context}
  end

  defp match_rules(_, [], _ts_match, _context) do
    :nomatch
  end

  defp match_rules([{:control_block, block} | _] = rules, ts_remaining, ts_match, context) do
    Enum.reduce(block, {:match, ts_remaining, ts_match, context}, fn
      _, :nomatch ->
        :nomatch

      :start, {:match, ts_r, ts_m, c} ->
        with {:match, ts_r, ts_m, c} <- match_rules(tl(rules), ts_r, ts_m, c) do
          first_token = List.last(ts_m)

          if !first_token || first_token.index == 0 do
            {:match, ts_r, ts_m, c}
          else
            :nomatch
          end
        end

      :end, {:match, ts_r, ts_m, c} ->
        if ts_remaining == [] do
          {:match, ts_r, ts_m, c}
        else
          :nomatch
        end

      {:eat, n}, {:match, ts_r, ts_m, c} ->
        with {:match, ts_r, ts_m1, c} when length(ts_m1) == n <-
               match_rules(tl(rules), ts_r, [], c) do
          {:match, ts_r, ts_m1 ++ ts_m, c}
        else
          e ->
            IO.inspect(e, label: "e")

            :nomatch
        end

      t, _ ->
        raise "Unimplemented :control_block instruction: #{inspect(t)}"
    end)
  end

  defp match_rules([{:word, word, ctl} | _] = rules, [t | _] = ts_remaining, ts_match, context) do
    test = fn -> t.value == word end
    boolean_match(t, test, ctl, context, rules, ts_remaining, ts_match, context)
  end

  defp match_rules([{:or, seqs, ctl} | _] = rules, ts_remaining, ts_match, context) do
    with {:match, ts_remaining, inner, context} <-
           match_any_list_of_rules(seqs, ts_remaining, [], context) do
      context = opt_assign(ctl, inner, context)
      match_rules(tl(rules), ts_remaining, inner ++ ts_match, context)
    end
  end

  defp match_rules([{:regex, re, ctl} | _] = rules, [t | _] = ts_remaining, ts_match, context) do
    test = fn -> Regex.match?(re, t.raw) end
    boolean_match(t, test, ctl, context, rules, ts_remaining, ts_match, context)
  end

  defp match_rules([{:any, _, ctl} | _] = rules, ts_remaining, ts_match, context) do
    with {eaten, ts_remaining} <- match_eat_tokens(ctl[:eat], tl(rules), ts_remaining, []) do
      context = opt_assign(ctl, eaten, context)
      match_rules(tl(rules), ts_remaining, eaten ++ ts_match, context)
    end
  end

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

  defp boolean_match(t, test, ctl, context, rules, ts_remaining, ts_match, context) do
    case test.() do
      true ->
        context = opt_assign(ctl, [t], context)
        match_rules(tl(rules), tl(ts_remaining), [t | ts_match], context)

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
