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
end
