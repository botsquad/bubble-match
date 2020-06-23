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

  use BubbleLib.DslStruct,
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
    %M{text: "", tokenizations: :digraph.new()}
  end

  def naive_tokenize(input) when is_binary(input) do
    tokens = Tokenizer.tokenize(input)
    graph = build_token_graph(tokens)
    %M{text: input, tokenizations: graph}
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
      no_punct = tokens |> Enum.reject(&(&1.value.pos == "PUNCT"))

      %M{text: text, tokenizations: both_if_different(no_punct, tokens)}
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

    case Enum.member?(m.tokenizations, tokenization) do
      false -> %M{m | tokenizations: [tokenization | m.tokenizations]}
      true -> m
    end
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
        {a, _} = Enum.split(token_sequence, start_idx)

        (a ++ replace_tokens)
        |> reindex()

      start_idx == nil and end_idx != nil ->
        {_, b} = Enum.split(token_sequence, end_idx + 1)

        (replace_tokens ++ b)
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

  defp both_if_different(a, a), do: [a]
  defp both_if_different(a, b), do: [a, b]

  defp build_token_graph(tokens) do
    graph = :digraph.new([:acyclic])
    :digraph.add_vertex(graph, :start)
    :digraph.add_vertex(graph, :end)
    build_token_graph(tokens, :start, graph)
  end

  defp build_token_graph([], _prev, graph) do
    graph
  end

  defp build_token_graph([last], prev, graph) do
    :digraph.add_vertex(graph, last)
    :digraph.add_vertex(graph, prev)
    :digraph.add_vertex(graph, :end)
    :digraph.add_edge(graph, prev, last)
    :digraph.add_edge(graph, last, :end)
    graph
  end

  defp build_token_graph([a, b | rest], prev, graph) do
    :digraph.add_vertex(graph, a)
    :digraph.add_vertex(graph, b)
    :digraph.add_edge(graph, prev, a)

    if Token.punct?(a) do
      :digraph.add_edge(graph, prev, b)
    end

    build_token_graph([b | rest], a, graph)
  end

  def print_dot(sentence) do
    IO.puts("digraph {")

    IO.puts("  start[label=\"START\"]")
    IO.puts("  end[label=\"END\"]")

    for v <- :digraph.vertices(sentence.tokenizations), v != :start, v != :end do
      IO.puts("  #{vertex_id(v)}[label=\"#{v.value}\"]")
    end

    for e <- :digraph.edges(sentence.tokenizations) do
      {_, from, to, _} = :digraph.edge(sentence.tokenizations, e)

      IO.puts("  #{vertex_id(from)} -> #{vertex_id(to)}")
    end

    IO.puts("}")
  end

  defp vertex_id(:start), do: "start"
  defp vertex_id(:end), do: "end"
  defp vertex_id(v), do: "v#{v.index}"
end

defimpl String.Chars, for: BubbleMatch.Sentence do
  def to_string(%BubbleMatch.Sentence{text: text}), do: text
end

require BubbleLib.DslStruct
BubbleLib.DslStruct.jason_derive(BubbleMatch.Sentence)
