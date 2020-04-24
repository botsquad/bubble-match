defmodule BubbleExpr.Sentence do
  defstruct text: nil, tokens: []
  alias BubbleExpr.Token
  alias __MODULE__, as: M

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

    defparsecp(
      :sentence,
      choice([
        ws,
        optional(ws)
        |> parsec(:word)
        |> repeat(ws |> parsec(:word))
        |> optional(ws)
      ])
    )

    def tokenize(input) do
      case sentence(input) do
        {:ok, tokens, "", _, _, _} ->
          Enum.with_index(tokens)
          |> Enum.map(fn {token, index} ->
            %{token | index: index}
          end)
      end
    end
  end

  def naive_tokenize("") do
    %M{text: "", tokens: []}
  end

  def naive_tokenize(input) do
    tokens = Tokenizer.tokenize(input)
    %M{text: input, tokens: tokens}
  end

  @doc """
  Adds an alternative intepretation
  """
  def replace_tokens(%M{} = m, start_index, end_index, new_tokens) do
    {start_tokens, _} = Enum.split(m.tokens, start_index)
    {_, end_tokens} = Enum.split(m.tokens, end_index)
    m = %M{m | tokens: start_tokens ++ new_tokens ++ end_tokens}

    IO.inspect({m.text, Enum.join(Enum.map(m.tokens, & &1.raw))}, label: "m.text != Enum.join(Enum.map(m.tokens, & &1.raw))")

    # ensure we are still a valid sentence
    if m.text != Enum.join(Enum.map(m.tokens, & &1.raw), " ") do
      raise RuntimeError, "replace_tokens differ from original sentence"
    end

    m
  end
end
