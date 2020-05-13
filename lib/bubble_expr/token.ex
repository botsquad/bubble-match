defmodule BubbleExpr.Token do
  @derive Jason.Encoder
  use BubbleExpr.DslStruct,
    raw: nil,
    value: nil,
    start: nil,
    end: nil,
    type: nil,
    index: nil

  alias __MODULE__, as: M

  def from_spacy(t) do
    value =
      Map.take(t, ~w(lemma pos norm tag))
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
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

  def pos?(%M{type: :spacy, value: %{pos: tag}}, tag) do
    true
  end

  def pos?(%M{type: :spacy, value: %{tag: tag}}, tag) do
    true
  end

  def pos?(_, _) do
    false
  end

  def word?(%M{type: :spacy} = t, word) do
    t.value.norm == word || t.value.lemma == word
  end

  def word?(%M{} = t, word) do
    t.value == word
  end

  def entity?(%M{} = t, kind) do
    t.type == :entity and t.value.kind == kind
  end

  def regex?(%M{} = t, re) do
    Regex.match?(re, t.raw)
  end

  def from_spacy_entity(ent, text) do
    {start, end_} = {ent["start"], ent["end"]}
    raw = String.slice(text, start, end_ - start)

    %M{
      type: :entity,
      value: %{kind: ent["label"], provider: "spacy", value: raw},
      start: start,
      end: end_,
      raw: raw
    }
  end

  def from_duckling_entity(ent) do
    {start, end_} = {ent["start"], ent["end"]}

    %M{
      type: :entity,
      value: %{kind: ent["dim"], provider: "duckling", value: ent["value"]},
      start: start,
      end: end_,
      raw: ent["body"]
    }
  end
end

defimpl String.Chars, for: BubbleExpr.Token do
  def to_string(%BubbleExpr.Token{raw: raw}), do: raw
end
