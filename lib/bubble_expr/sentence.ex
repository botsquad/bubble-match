defmodule BubbleExpr.Sentence do
  defstruct text: nil, tokens: []
  alias BubbleExpr.Token

  defmodule Tokenizer do
    import NimbleParsec

    @ws [9, 10, 11, 12, 13, 32]
    ws = ignore(ascii_char(@ws) |> concat(repeat(ascii_char(@ws))))
    text = ascii_string(Enum.map(@ws, &{:not, &1}), min: 1)

    defparsec(
      :word,
      text
      |> post_traverse(:match_and_emit_tag)
    )

    defp match_and_emit_tag(_rest, [word], context, _, offset) do
      {[
         %Token{
           raw: word,
           start: offset - String.length(word),
           end: offset,
           value: normalize(word),
           type: :naive
         }
       ], context}
    end

    defp normalize(word) do
      Regex.replace(~r/[^\w+]/, word, "")
      |> String.downcase()
    end

    defparsec(
      :sentence,
      choice([
        ws,
        optional(ws)
        |> parsec(:word)
        |> repeat(ws |> parsec(:word))
        |> optional(ws)
      ])
    )
  end

  def naive_tokenize("") do
    %__MODULE__{text: "", tokens: []}
  end

  def naive_tokenize(input) do
    {:ok, tokens, "", _, _, _} = Tokenizer.sentence(input)
    %__MODULE__{text: input, tokens: tokens}
  end
end
