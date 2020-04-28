defmodule BubbleExpr.Sentence.Tokenizer do
  import NimbleParsec
  alias BubbleExpr.Token

  @ws [9, 10, 11, 12, 13, 32]
  ws = ascii_string(@ws, min: 1)

  @punct [
    ??,
    ?!,
    ?@,
    ?#,
    ?$,
    ?%,
    ?^,
    ?&,
    ?*,
    ?(,
    ?),
    ?;,
    ?:,
    ?,,
    ?.,
    ?<,
    ?>,
    ?[,
    ?],
    ?",
    ?',
    ?~,
    ?`
  ]

  punct =
    ascii_char(@punct)
    |> tag(:punct)

  text =
    ascii_string(Enum.map(@ws, &{:not, &1}) ++ Enum.map(@punct, &{:not, &1}), min: 1)
    |> tag(:word)

  defparsec(
    :word,
    choice([text, punct])
    |> optional(ws)
    |> post_traverse(:match_and_emit_tag)
  )

  defp match_and_emit_tag(_rest, inp, context, _, offset) do
    {value, type, raw} =
      case inp do
        [{:word, [text]}] ->
          {normalize(text), :naive, text}

        [ws, {:word, [text]}] ->
          {normalize(text), :naive, text <> ws}

        [{:punct, text}] ->
          t = IO.chardata_to_string(text)
          {t, :punct, t}

        [ws, {:punct, text}] ->
          t = IO.chardata_to_string(text)
          {t, :punct, t <> ws}
      end

    start = offset - String.length(raw)
    end_ = start + String.length(String.trim(raw))

    {[
       %Token{
         raw: raw,
         start: start,
         end: end_,
         value: value,
         type: type
       }
     ], context}
  end

  defp normalize(word) do
    Regex.replace(~r/[^\w+]/, word, "")
    |> String.downcase()
  end

  defparsecp(
    :sentence,
    optional(ws)
    |> parsec(:word)
    |> repeat(parsec(:word))
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
