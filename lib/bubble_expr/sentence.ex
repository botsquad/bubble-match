defmodule BubbleExpr.Sentence do
  defstruct text: nil, tokenizations: []
  #
  alias BubbleExpr.Sentence.Tokenizer
  alias BubbleExpr.Token

  alias __MODULE__, as: M

  def naive_tokenize("") do
    %M{text: "", tokenizations: [[]]}
  end

  def naive_tokenize(input) do
    tokens = Tokenizer.tokenize(input)
    %M{text: input, tokenizations: [tokens]}
  end

  def from_spacy(%{"text" => text, "tokens" => tokens, "ents" => ents}) do
    raw_tokens = Enum.map(tokens, &Token.from_spacy/1)

    tokenizations =
      case ents do
        [] -> [raw_tokens]
        _ -> [spacy_replace_with_entities(ents, raw_tokens, text), raw_tokens]
      end

    %M{text: text, tokenizations: tokenizations}
  end

  defp spacy_replace_with_entities(ents, raw_tokens, text) do
    ents
    |> Enum.map(&Token.from_spacy_entity(&1, text))
    |> Enum.reduce(raw_tokens, fn entity_token, tokens ->
      replace_tokens(tokens, [entity_token])
    end)
  end

  def add_duckling_entities(%M{} = m, []), do: m

  def add_duckling_entities(%M{} = m, ents) do
    raw_tokens = List.last(m.tokenizations)

    duckling_tokenization =
      ents
      |> Enum.map(&Token.from_duckling_entity(&1))
      |> Enum.reduce(raw_tokens, fn entity_token, tokens ->
        replace_tokens(tokens, [entity_token])
      end)

    %M{m | tokenizations: [duckling_tokenization | m.tokenizations]}
  end

  defp replace_tokens(token_sequence, replace_tokens) do
    # find
    start = List.first(replace_tokens).start
    end_ = List.last(replace_tokens).end

    start_idx = Enum.find_index(token_sequence, &(&1.start == start))
    end_idx = Enum.find_index(token_sequence, &(&1.end == end_))

    if start_idx != nil and end_idx != nil and end_idx >= start_idx do
      {a, _} = Enum.split(token_sequence, start_idx)
      {_, b} = Enum.split(token_sequence, end_idx + 1)

      (a ++ replace_tokens ++ b)
      |> reindex()
    else
      :error
    end
  end

  defp reindex(tokens) do
    tokens
    |> Enum.with_index()
    |> Enum.map(fn {t, index} ->
      %{t | index: index}
    end)
  end
end
