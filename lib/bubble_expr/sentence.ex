defmodule BubbleExpr.Sentence do
  defstruct text: nil, tokenizations: []
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

  def from_spacy(%{"text" => text, "tokens" => tokens} = result) do
    raw_tokens = Enum.map(tokens, &Token.from_spacy/1)

    %M{text: text, tokenizations: [raw_tokens]}
    |> add_spacy_entities(result)
  end

  def add_spacy_entities(%M{} = m, %{"ents" => []}), do: m

  def add_spacy_entities(%M{} = m, %{"ents" => ents, "text" => text}) do
    sequences = Enum.map(ents, &[Token.from_spacy_entity(&1, text)])
    add_tokenization(m, sequences)
  end

  def add_duckling_entities(%M{} = m, []), do: m

  def add_duckling_entities(%M{} = m, ents) do
    sequences = Enum.map(ents, &[Token.from_duckling_entity(&1)])
    add_tokenization(m, sequences)
  end

  def add_tokenization(%M{} = m, replace_token_sequences) do
    raw_tokens = List.last(m.tokenizations)

    tokenization =
      replace_token_sequences
      |> Enum.reduce(raw_tokens, fn seq, tokens ->
        replace_tokens(tokens, seq)
      end)

    %M{m | tokenizations: [tokenization | m.tokenizations]}
  end

  ###

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
      raise RuntimeError, "Token not found at start = #{start}, end = #{end_}"
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
