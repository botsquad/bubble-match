defmodule BubbleMatch.Matcher do
  @moduledoc false

  alias BubbleMatch.{Parser, Sentence, Token}

  def match(expr, input) when is_list(input) do
    Enum.reduce(input, :nomatch, fn
      input, :nomatch ->
        match(expr, input)

      _, result ->
        result
    end)
  end

  def match(expr, input) when is_binary(expr) do
    with {:ok, expr} <- Parser.parse(expr) do
      match(expr, input)
    end
  end

  def match(expr, input) when is_binary(input) do
    sentence = Sentence.naive_tokenize(input)
    match(expr, sentence)
  end

  def match(%BubbleMatch{} = expr, %Sentence{} = sentence) do
    Enum.reduce_while(sentence.tokenizations, :nomatch, fn tokens, acc ->
      case match_rules(expr.ast, tokens, [], %{}) do
        {:match, _, _, context} ->
          {:halt, {:match, context}}

        :nomatch ->
          {:cont, acc}
      end
    end)
  end

  defp match_rules(nil, _ts_remaining, _ts_match, _context) do
    :nomatch
  end

  defp match_rules([], ts_remaining, ts_match, context) do
    {:match, ts_remaining, ts_match, context}
  end

  defp match_rules([{:sentence_start, [], _}, {:sentence_end, [], _} | _], [], [], context) do
    {:match, [], [], context}
  end

  defp match_rules([{:sentence_end, [], _}], [], ts_match, context) do
    {:match, [], ts_match, context}
  end

  defp match_rules([{_, _, ctl}], [], ts_match, context) do
    case ctl[:repeat] do
      {0, _, _} -> {:match, [], ts_match, context}
      _ -> :nomatch
    end
  end

  defp match_rules([{_, _, _} | _remain], [], _ts_match, _context) do
    :nomatch
  end

  defp match_rules([{_, _, ctl} = rule | rest], ts_remaining, ts_match, context) do
    repeat = ctl[:repeat] || {1, 1, :greedy}

    with {:match, ts_remaining, inner, context} <-
           match_rule_repeat(repeat, rule, rest, ts_remaining, [], context) do
      context = opt_assign(ctl, inner, context)
      match_rules(rest, ts_remaining, inner ++ ts_match, context)
    end
  end

  defp match_rule_repeat({0, 0, _}, _, _, ts_remaining, ts_match, context) do
    {:match, ts_remaining, ts_match, context}
  end

  defp match_rule_repeat({1, 1, _}, rule, rls_remaining, ts_remaining, ts_match, context) do
    with {:match, ts_remaining, inner, context} <-
           match_rule(rule, rls_remaining, ts_remaining, context) do
      {:match, ts_remaining, inner ++ ts_match, context}
    end
  end

  defp match_rule_repeat({n, n, g}, rule, rls_remaining, ts_remaining, ts_match, context)
       when n > 1 do
    with {:match, ts_remaining, inner, context} <-
           match_rule(rule, rls_remaining, ts_remaining, context) do
      match_rule_repeat(
        {n - 1, n - 1, g},
        rule,
        rls_remaining,
        ts_remaining,
        inner ++ ts_match,
        context
      )
    end
  end

  defp match_rule_repeat({n, _m, :greedy}, _, _, ts_remaining, _, _)
       when n > length(ts_remaining) do
    :nomatch
  end

  defp match_rule_repeat({n, m, :greedy}, rule, rls_remaining, ts_remaining, ts_match, context)
       when m > n do
    m = prevent_infinity(m, n, ts_remaining)

    {eat_tokens, ts_remaining_split} = Enum.split(ts_remaining, m)

    with {:match, _, _, context} <- match_rule(rule, [], eat_tokens, context),
         {:match, _ts_remaining, _inner, context} <-
           match_rules(rls_remaining, ts_remaining_split, ts_match, context) do
      {:match, ts_remaining_split, Enum.reverse(eat_tokens), context}
    else
      :nomatch ->
        match_rule_repeat(
          {n, m - 1, :greedy},
          rule,
          rls_remaining,
          ts_remaining,
          ts_match,
          context
        )
    end
  end

  defp match_rule_repeat({n, m, :nongreedy}, rule, rls_remaining, ts_remaining, ts_match, context)
       when m > n do
    with {eaten, ts_remaining} <-
           match_nongreedy({n, m}, rule, rls_remaining, ts_remaining, ts_match) do
      {:match, ts_remaining, eaten ++ ts_match, context}
    end
  end

  defp match_rule({:any, [], _}, _rls_remaining, ts_remaining, context) do
    fn _t -> true end
    |> boolean_match(ts_remaining, context)
  end

  defp match_rule({:word, word, _}, _rls_remaining, ts_remaining, context) do
    fn t -> Token.word?(t, word) end
    |> boolean_match(ts_remaining, context)
  end

  defp match_rule({:entity, e, _}, _rls_remaining, ts_remaining, context) do
    fn t -> Token.entity?(t, e) end
    |> boolean_match(ts_remaining, context)
  end

  defp match_rule({:regex, _re, _}, _rls_remaining, [], _context) do
    :nomatch
  end

  defp match_rule({:regex, re, _}, _rls_remaining, [t | _] = ts_remaining, context) do
    input_str =
      case ts_remaining do
        [%{index: 0} | _] -> Enum.map(ts_remaining, & &1.raw)
        _ -> [" " | Enum.map(ts_remaining, & &1.raw)]
      end
      |> IO.chardata_to_string()

    case Regex.scan(re, input_str) do
      [[capture | groups] | _] ->
        [before, _] = String.split(input_str, capture, parts: 2)

        start_idx = t.start + String.length(before)
        {_ignore, rest} = Enum.split_with(ts_remaining, &(&1.end < start_idx))
        end_idx = start_idx + String.length(capture)
        {ts_match, ts_remaining} = Enum.split_with(rest, &(&1.start <= end_idx))

        context = opt_add_regex_captures(groups, context, re, input_str)
        {:match, ts_remaining, Enum.reverse(ts_match), context}

      [] ->
        :nomatch
    end
  end

  defp match_rule({:pos, tag, _}, _rls_remaining, ts_remaining, context) do
    fn t -> Token.pos?(t, tag) end
    |> boolean_match(ts_remaining, context)
  end

  defp match_rule({:concept, {m, f, a}, _}, _rls_remaining, ts_remaining, context) do
    fn t -> apply(m, f, [t | a]) end
    |> boolean_match(ts_remaining, context)
  end

  defp match_rule({:or, seqs, _}, _rls_remaining, ts_remaining, context) do
    with {:match, ts_remaining, inner, context} <-
           match_any_list_of_rules(seqs, ts_remaining, [], context) do
      {:match, ts_remaining, inner, context}
    end
  end

  defp match_rule({:literal, str, _}, _rls_remaining, ts_remaining, context) do
    ts_remaining
    |> Enum.reduce_while(
      {[], ts_remaining, str},
      fn
        t, {matched, remaining, str} ->
          raw = String.trim_trailing(t.raw) |> Token.base_form()

          if String.starts_with?(str, raw) do
            case String.trim_leading(str, raw) do
              "" ->
                {:halt, {:match, tl(remaining), [t | matched], context}}

              str ->
                {:cont, {[t | matched], tl(remaining), String.trim_leading(str)}}
            end
          else
            {:halt, :nomatch}
          end
      end
    )
    |> case do
      {_, _, _} -> :nomatch
      r -> r
    end
  end

  defp match_rule({:sentence_start, [], _}, _rls_remaining, ts_remaining, context) do
    case ts_remaining do
      [%{index: 0} | _] ->
        {:match, ts_remaining, [], context}

      _ ->
        :nomatch
    end
  end

  defp match_rule({:sentence_end, [], _}, _rls_remaining, _ts_remaining, _context) do
    :nomatch
  end

  ###

  defp match_nongreedy({n, _m}, _rule, _rules, ts_remaining, _add)
       when n > length(ts_remaining) do
    :nomatch
  end

  defp match_nongreedy({n, n}, _rule, _rules, ts_remaining, add) do
    {left, right} = Enum.split(ts_remaining, n)
    {Enum.reverse(left) ++ add, right}
  end

  defp match_nongreedy({n, m}, rule, rules, ts_remaining, add) when n > 0 do
    {left, right} = Enum.split(ts_remaining, n)
    {Enum.reverse(left), right}
    m = prevent_infinity(m, n, ts_remaining)
    match_nongreedy({0, m - n}, rule, rules, right, add ++ Enum.reverse(left))
  end

  defp match_nongreedy({0, n}, _rule, rules, ts_remaining, add) do
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

  defp prevent_infinity(:infinity, _n, tokens), do: length(tokens)
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

  defp opt_add_regex_captures([], context, _regex, _input) do
    context
  end

  defp opt_add_regex_captures(_groups, context, regex, input) do
    Regex.named_captures(regex, input)
    |> Enum.reduce(context, fn {k, v}, ctx ->
      Map.put(ctx, k, [%Token{raw: v}])
    end)
  end
end
