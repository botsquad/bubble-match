defmodule BubbleExpr.Sentence do
  @moduledoc """
  A data structure which holds a tokenized sentence.

  The struct contains the text of the sentence (in the *text*
  property), and a list of *tokenizations*. Normally, a sentence has
  just one tokenization, but adding entities to the sentence might
  cause several tokens in the sentence to be replaed with an entity
  token, thus creating the need for multiple tokenizations (as you
  still might want to match on the original sentence, e.g. in the case
  of a falsely identified entitiy)

  """

  @derive Jason.Encoder
  use BubbleExpr.DslStruct,
    text: nil,
    tokenizations: []

  alias BubbleExpr.Sentence.Tokenizer
  alias BubbleExpr.Token

  @type t :: __MODULE__

  alias __MODULE__, as: M

  @doc """
  Tokenize an input into individual tokens.

  As the name suggests, this tokenization is quite naive. It only
  splits strings on whitespace and punctuation, disregarding any
  language-specific information. However, for 'basic' use cases, and
  for our test suite, it is good enough.
  """
  @spec naive_tokenize(input :: String.t()) :: [t()]
  def naive_tokenize(input)

  def naive_tokenize("") do
    %M{text: "", tokenizations: [[]]}
  end

  def naive_tokenize(input) when is_binary(input) do
    tokens = Tokenizer.tokenize(input)
    %M{text: input, tokenizations: [tokens]}
  end

  @doc """
  Convert a JSON blob from Spacy NLP data into a list of sentences

  This function takes the output of Spacy's [Doc.to_json][spacy]
  function and converts it into a list of sentences.

  [spacy]: https://spacy.io/api/doc#to_json
  """
  @spec sentences_from_spacy(spacy_json :: map()) :: [t()]
  def sentences_from_spacy(spacy_json) do
    spacy_sentences_split(spacy_json["sents"], spacy_json, [])
    |> Enum.map(fn {text, tokens, entities} ->
      %M{text: text, tokenizations: [tokens]}
      |> add_spacy_entities(entities, spacy_json)
    end)
  end

  defp spacy_sentences_split([], _result, acc) do
    Enum.reverse(acc)
  end

  defp spacy_sentences_split([%{"start" => start, "end" => end_} | rest], result, acc) do
    s_text = String.slice(result["text"], start, end_ - start)

    s_tokens =
      result["tokens"]
      |> Enum.filter(&(&1["start"] >= start && &1["end"] <= end_))
      |> Enum.map(&Token.from_spacy/1)
      |> reindex()

    s_ents = result["ents"] |> Enum.filter(&(&1["start"] >= start && &1["end"] <= end_))
    spacy_sentences_split(rest, result, [{s_text, s_tokens, s_ents} | acc])
  end

  defp add_spacy_entities(%M{} = m, [], _), do: m

  defp add_spacy_entities(%M{} = m, ents, %{"text" => text}) do
    sequences = Enum.map(ents, &[Token.from_spacy_entity(&1, text)])
    add_tokenization(m, sequences)
  end

  @doc """
  Enrich the given sentence with entities extracted via Duckling

  This function takes the output of the [Duckling JSON
  format][duckling] and enriches the given sentence with the entities
  that were found using Duckling.

  [duckling]: https://github.com/facebook/duckling
  """
  @spec add_duckling_entities(sentence :: t(), entities :: list()) :: t()
  def add_duckling_entities(%M{} = sentence, []), do: sentence

  def add_duckling_entities(%M{} = sentence, entities) do
    sequences = Enum.map(entities, &[Token.from_duckling_entity(&1)])
    add_tokenization(sentence, sequences)
  end

  @doc false
  def add_tokenization(%M{} = m, replace_token_sequences) do
    raw_tokens = List.last(m.tokenizations)

    tokenization =
      replace_token_sequences
      |> Enum.reduce(raw_tokens, fn seq, tokens ->
        replace_tokens(tokens, seq)
      end)

    %M{m | tokenizations: [tokenization | m.tokenizations]}
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
      # raise RuntimeError, "Token not found at start = #{start}, end = #{end_}"
      token_sequence
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

defimpl String.Chars, for: BubbleExpr.Sentence do
  def to_string(%BubbleExpr.Sentence{text: text}), do: text
end
