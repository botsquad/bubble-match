defmodule BubbleMatch.Sentence do
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

  use BubbleMatch.DslStruct,
    text: nil,
    tokenizations: []

  alias BubbleMatch.Sentence.Tokenizer
  alias BubbleMatch.Token

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
    %M{text: input, tokenizations: both_if_different(no_punct(tokens), tokens)}
  end

  @doc """
  Convert a JSON blob from Spacy NLP data into a sentence.

  This function takes the output of Spacy's [Doc.to_json][spacy]
  function and converts it into a sentence.

  Note that the Spacy tokenizer detects multiple sentences. However,
  in many cases the result is suboptimal and therefore we always
  construct a single sentence, given our use case of chat messages.

  [spacy]: https://spacy.io/api/doc#to_json
  """
  @spec from_spacy(spacy_json :: map()) :: t()
  def from_spacy(%{"sents" => []} = s) do
    %M{text: s["text"]}
  end

  def from_spacy(spacy_json) do
    sents = spacy_json["sents"]
    start = sents |> Enum.map(& &1["start"]) |> Enum.min()
    end_ = sents |> Enum.map(& &1["end"]) |> Enum.max()
    text = String.slice(spacy_json["text"], start, end_ - start)

    tokens =
      spacy_json["tokens"]
      |> Enum.map(&Token.from_spacy/1)
      |> reindex()
      |> Enum.chunk_every(2, 1, [nil])
      |> Enum.map(fn
        [tok, nil] -> tok
        [tok, next] -> %{tok | end: next.start - 1}
      end)
      |> Enum.map(fn tok ->
        %{tok | raw: String.pad_trailing(tok.raw, tok.end - tok.start + 1)}
      end)

    entities = spacy_json["ents"]

    %M{text: text, tokenizations: both_if_different(no_punct(tokens), tokens)}
    |> add_spacy_entities(entities, spacy_json)
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
      |> Enum.reduce(raw_tokens, fn seq, toks ->
        replace_tokens(toks, seq)
      end)

    tokenizations = both_if_different(no_punct(tokenization), tokenization)
    %M{m | tokenizations: Enum.uniq(tokenizations ++ m.tokenizations)}
  end

  defp replace_tokens(token_sequence, replace_tokens) do
    # find
    start = List.first(replace_tokens).start
    end_ = List.last(replace_tokens).end

    start_idx = Enum.find_index(token_sequence, &(&1.start == start))
    end_idx = Enum.find_index(token_sequence, &(&1.end == end_))

    cond do
      start_idx != nil and end_idx != nil and end_idx >= start_idx ->
        {a, _} = Enum.split(token_sequence, start_idx)
        {_, b} = Enum.split(token_sequence, end_idx + 1)

        (a ++ replace_tokens ++ b)
        |> reindex()

      start_idx != nil and end_idx == nil ->
        {a, b} = Enum.split(token_sequence, start_idx)

        (a ++ replace_tokens ++ b)
        |> reindex()

      start_idx == nil and end_idx != nil ->
        {a, b} = Enum.split(token_sequence, end_idx + 1)

        (a ++ replace_tokens ++ b)
        |> reindex()

      true ->
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

  defp both_if_different(a, b, rest \\ [])
  defp both_if_different(a, a, rest), do: [a | rest]
  defp both_if_different(a, b, rest), do: [a, b | rest]

  defp no_punct(tokens) do
    tokens |> Enum.reject(&Token.punct?/1)
  end
end

defimpl String.Chars, for: BubbleMatch.Sentence do
  def to_string(%BubbleMatch.Sentence{text: text}), do: text
end

require BubbleMatch.DslStruct
BubbleMatch.DslStruct.jason_derive(BubbleMatch.Sentence)
