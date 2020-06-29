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
    graph = new_graph() |> build_token_graph(tokens)
    %M{text: input, tokenizations: graph}
  end

  @doc """
  Convert a JSON blob from Spacy NLP data into a sentence.

  This function takes the output of Spacy's [Doc.to_json][spacy]
  function and creates a Sentence struct from it. Note that the struct
  might actually contain more than one sentence.

  [spacy]: https://spacy.io/api/doc#to_json
  """
  @spec from_spacy(spacy_json :: map()) :: [t()]
  def from_spacy(spacy_json) do
    text = spacy_json["text"]

    tokens =
      spacy_json["tokens"]
      |> Enum.map(&Token.from_spacy/1)

    graph = new_graph()

    for %{"start" => start, "end" => end_} <- spacy_json["sents"] do
      ts = Enum.filter(tokens, &(&1.start >= start && &1.end <= end_))
      build_token_graph(graph, ts)
    end

    # add entities
    ents = Enum.map(spacy_json["ents"], &Token.from_spacy_entity(&1, text))
    add_entities(graph, ents)
    %M{text: text, tokenizations: graph}
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
    ents = Enum.map(entities, &Token.from_duckling_entity(&1))

    add_entities(sentence.tokenizations, ents)
    sentence
  end

  ###

  defp new_graph() do
    graph = :digraph.new([:acyclic])
    :digraph.add_vertex(graph, :start)
    :digraph.add_vertex(graph, :end)
    graph
  end

  defp build_token_graph(graph, tokens) do
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
    build_token_graph([b | rest], a, graph)
  end

  defp add_entities(graph, ents) do
    for %{start: start, end: end_} = ent <- ents do
      ent = Map.put(ent, :index, :erlang.system_time())
      :digraph.add_vertex(graph, ent)

      t_start =
        :digraph.vertices(graph)
        |> Enum.find(&(is_map(&1) && &1.end == start - 1))

      if t_start do
        :digraph.add_edge(graph, t_start, ent)
      else
        :digraph.add_edge(graph, :start, ent)
      end

      t_end =
        :digraph.vertices(graph)
        |> Enum.find(&(is_map(&1) && (&1.start == end_ + 1 || &1.start == end_)))

      if t_end do
        :digraph.add_edge(graph, ent, t_end)
      else
        :digraph.add_edge(graph, ent, :end)
      end
    end

    graph
  end

  def make_dot(sentence) do
    [
      "digraph {",
      "  start[label=\"START\"]",
      "  end[label=\"END\"]",
      for v <- :digraph.vertices(sentence.tokenizations), v != :start, v != :end do
        "  #{vertex_id(v)}[label=\"#{v}\"]"
      end,
      for e <- :digraph.edges(sentence.tokenizations) do
        {_, from, to, _} = :digraph.edge(sentence.tokenizations, e)

        "  #{vertex_id(from)} -> #{vertex_id(to)}"
      end,
      "}"
    ]
    |> List.flatten()
    |> Enum.intersperse("\n")
    |> IO.chardata_to_string()
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
