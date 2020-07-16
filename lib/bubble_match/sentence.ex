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
    %M{text: "", tokenizations: new_graph()}
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
    sents = spacy_json["sents"]

    # add all sentences
    graph =
      Enum.reduce(sents, graph, fn %{"start" => start, "end" => end_}, graph ->
        ts = Enum.filter(tokens, &(&1.start >= start && &1.end <= end_))
        build_token_graph(graph, ts)
      end)

    [_ | pairs] = Enum.zip([nil | sents], sents)

    # add edge between sentences
    graph =
      Enum.reduce(pairs, graph, fn {%{"end" => end_}, %{"start" => start}}, graph ->
        {t_start, t_end} = find_start_end(graph, start, end_)
        Graph.add_edge(graph, t_start, t_end)
      end)

    # add entities
    ents = Enum.map(spacy_json["ents"], &Token.from_spacy_entity(&1, text))
    graph = add_entities(graph, ents)
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

    graph = add_entities(sentence.tokenizations, ents)
    %M{sentence | tokenizations: graph}
  end

  def skip_punct(%M{tokenizations: graph} = m) do
    graph =
      Enum.reduce(Graph.vertices(graph), graph, fn v, graph ->
        connect_punct(graph, v, nil)
      end)

    %{m | tokenizations: graph}
  end

  ###

  defp connect_punct(graph, v, first) do
    case out_vertices(graph, v) |> Enum.split_with(&Token.punct?/1) do
      {[], []} ->
        graph

      {p, []} ->
        Enum.reduce(p, graph, fn v2, graph ->
          connect_punct(graph, v2, first || v)
        end)

      {_, vs} ->
        if first && not Token.punct?(first) do
          Enum.reduce(vs, graph, fn v2, graph ->
            Graph.add_edge(graph, first, v2)
          end)
        else
          graph
        end
    end
  end

  defp new_graph() do
    Graph.new(type: :directed)
    |> Graph.add_vertices([:start, :end])
  end

  defp build_token_graph(graph, tokens) do
    build_token_graph(graph, tokens, :start)
  end

  defp build_token_graph(graph, [], _prev) do
    graph
  end

  defp build_token_graph(graph, [last], prev) do
    graph
    |> Graph.add_vertices([last, prev, :end])
    |> Graph.add_edge(prev, last)
    |> Graph.add_edge(last, :end)
  end

  defp build_token_graph(graph, [a, b | rest], prev) do
    graph
    |> Graph.add_vertices([a, b])
    |> Graph.add_edge(prev, a)
    |> build_token_graph([b | rest], a)
  end

  defp find_start_end(graph, start, end_) do
    t_start =
      Graph.vertices(graph)
      |> Enum.find(&(is_map(&1) && &1.end == start - 1))

    t_end =
      Graph.vertices(graph)
      |> Enum.find(&(is_map(&1) && (&1.start == end_ + 1 || &1.start == end_)))

    {t_start, t_end}
  end

  defp add_entities(graph, ents) do
    Enum.reduce(ents, graph, fn %{start: start, end: end_} = ent, graph ->
      {t_start, t_end} = find_start_end(graph, start, end_)
      graph = Graph.add_vertex(graph, ent)

      graph =
        if t_start do
          Graph.add_edge(graph, t_start, ent)
        else
          Graph.add_edge(graph, :start, ent)
        end

      graph =
        if t_end do
          Graph.add_edge(graph, ent, t_end)
        else
          Graph.add_edge(graph, ent, :end)
        end

      graph
    end)
  end

  def out_vertices(graph, vertex) do
    Graph.out_edges(graph, vertex)
    |> Enum.map(fn e -> e.v2 end)
  end

  def make_dot(sentence) do
    [
      "digraph {",
      "  start[label=\"START\"]",
      "  end[label=\"END\"]",
      for v <- Graph.vertices(sentence.tokenizations), v != :start, v != :end do
        "  #{vertex_id(v)}[label=\"#{v}\"]"
      end,
      for e <- Graph.edges(sentence.tokenizations) do
        "  #{vertex_id(e.v1)} -> #{vertex_id(e.v2)}"
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
