defmodule BubbleMatch.Token do
  @moduledoc """
  A token is a single word or a part of the sentence. A sentence is a sequence of tokens.

  Each token contains information and metadata that is used to match
  sentences on, and to extract information from.
  """

  @typedoc """

   Tokens contain the following fields:

   * `raw` - the raw text value of the token, including any surrounding
     whitespace.

   * `value` - the normalized value of the token. In the case of word
     tokens, this is usually the normalized, lowercased version of the
     word. In the case of entities, this value holds a map with keys
     `kind`, `provider` and `value`.

  * `start` - the start index; where in the original sentence the
    token starts.

  * `end` - the end index; where in the original sentence the
    token ends.

  * `index` - the (zero-based) token index number; 0 if it's the first
     token, 1 if it's the second, etc.

  * `type` - the type of the token; an atom, holding either `:entity`,
    `:spacy`, `:naive`, depending on the way the token was
    originally created.

  """
  @type t :: %__MODULE__{}

  use BubbleLib.DslStruct,
    raw: nil,
    value: nil,
    start: nil,
    end: nil,
    type: nil,
    index: nil

  alias BubbleMatch.{Entity, Unidekode}
  alias __MODULE__, as: M

  @doc """
  Given a single token in Spacy's JSON format, convert it into a token.
  """
  @spec from_spacy(spacy_json_token :: map()) :: t()
  def from_spacy(t) do
    value =
      Map.take(t, ~w(lemma pos norm tag))
      |> Enum.map(fn {k, v} -> {k, Unidekode.to_ascii(v)} end)
      |> Map.new()

    %M{
      type: :spacy,
      value: value,
      raw: t["string"],
      index: t["id"],
      start: t["start"],
      end: t["end"]
    }
  end

  @doc """
  Test whether a token is punctuation
  """
  def punct?(%M{type: :punct}) do
    true
  end

  def punct?(token) do
    pos?(token, "PUNCT") || pos?(token, "SYM")
  end

  @doc """
  Test whether a token mathces the given POS (part-of-speech) tag.
  """
  def pos?(%M{type: :spacy, value: %{"pos" => tag}}, tag) do
    true
  end

  def pos?(%M{type: :spacy, value: %{"tag" => tag}}, tag) do
    true
  end

  def pos?(_, _) do
    false
  end

  @doc """
  Test whether a token matches the given (optionally normalized) word.
  """
  def word?(%M{type: :spacy} = t, word) do
    t.value["norm"] == word || t.value["lemma"] == word
  end

  def word?(%M{} = t, word) do
    t.value == word || t.raw == word
  end

  @doc """
  Test whether a token is an entity of the given kind.
  """
  def entity?(%M{} = t, kind) do
    t.type == :entity and t.value.kind == kind
  end

  @doc """
  Constructs a token from a Spacy entity definition
  """
  def from_spacy_entity(spacy_entity_json, sentence_text) do
    {start, end_} = {spacy_entity_json["start"], spacy_entity_json["end"]}
    raw = String.slice(sentence_text, start, end_ - start)
    entity = Entity.new("spacy", Inflex.underscore(spacy_entity_json["label"]), raw)

    %M{
      type: :entity,
      value: entity,
      start: start,
      end: end_,
      raw: raw
    }
  end

  @doc """
  Constructs a token from a Duckling entity definition
  """
  def from_duckling_entity(duckling_entity) do
    {start, end_} = {duckling_entity["start"], duckling_entity["end"]}

    value = duckling_entity["value"]["value"]
    extra = duckling_entity["value"] |> Map.delete("value")

    entity = Entity.new("duckling", Inflex.underscore(duckling_entity["dim"]), value, extra)

    %M{
      type: :entity,
      value: entity,
      start: start,
      end: end_,
      raw: duckling_entity["body"]
    }
  end

  @doc """
  Get the base form of the given string; the downcased, ASCII version.
  """
  def base_form(str) do
    str
    |> String.trim()
    |> String.downcase()
    |> Unidekode.drop_accented()
    |> String.replace("’", "'")
    |> String.replace("ʼ", "'")
  end
end

defimpl String.Chars, for: BubbleMatch.Token do
  def to_string(%BubbleMatch.Token{raw: raw}), do: raw
end

require BubbleLib.DslStruct
BubbleLib.DslStruct.jason_derive(BubbleMatch.Token)
