defmodule BubbleExpr.Token do
  defstruct raw: nil, value: nil, start: nil, end: nil, type: nil, index: nil
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

  def test(%M{type: :spacy} = t, word) do
    t.value.norm == word || t.value.lemma == word
  end

  def test(%M{} = t, word) do
    t.value == word
  end

  def from_spacy_entity(ent, text) do
    {start, end_} = {ent["start"], ent["end"]}
    raw = String.slice(text, start, end_)

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
