defmodule BubbleExpr.Parser do
  import NimbleParsec

  alias BubbleExpr.Validator

  # ws       := [ ]+
  # word     := (A-Za-z)+
  # or_group := '(' ws? rule_seq (ws '|' ws rule_seq)* ws? ')'

  # rule     := word | or_group
  # rule_seq := rule | rule ws rule_seq

  @ws [9, 10, 11, 12, 13, 32]
  ws = ignore(ascii_char(@ws) |> concat(repeat(ascii_char(@ws))))

  @az ascii_char(Enum.to_list(?A..?Z) ++ Enum.to_list(?a..?z))

  string_literal =
    ignore(string("\""))
    |> repeat(utf8_char([{:not, ?"}]))
    |> reduce(:to_string)
    |> ignore(string("\""))
    |> unwrap_and_tag(:string_literal)

  word =
    @az
    |> concat(repeat(@az))
    |> reduce(:to_string)
    |> unwrap_and_tag(:word)

  or_group =
    ignore(string("("))
    |> optional(ws)
    |> parsec(:rule_seq)
    |> optional(
      repeat(
        ws
        |> ignore(string("|"))
        |> concat(ws)
        |> parsec(:rule_seq)
      )
    )
    |> optional(ws)
    |> ignore(string(")"))
    |> tag(:or_group)

  defp to_symbol([{s, []}]), do: s

  symbol = fn string, symbol ->
    ignore(string(string)) |> tag(symbol) |> reduce(:to_symbol)
  end

  defcombinatorp(
    :control_code,
    choice([
      # start of sentence
      symbol.("Start", :start),
      # end of sentence
      symbol.("End", :end),
      # slot assignment
      ignore(string("="))
      |> concat(@az)
      |> repeat(@az)
      |> reduce(:to_string)
      |> tag(:assign),
      # eat a range of tokens
      integer(min: 0)
      |> ignore(string("-"))
      |> integer(min: 1)
      |> tag(:eat),
      # eat a single token
      integer(min: 1)
      |> unwrap_and_tag(:eat),
      empty()
    ])
  )

  control_block =
    ignore(string("["))
    |> optional(ws)
    |> parsec(:control_code)
    |> repeat(ignore(string(";")) |> parsec(:control_code))
    |> optional(ws)
    |> ignore(string("]"))
    |> tag(:control_block)

  defcombinatorp(
    :rule,
    choice([
      word,
      string_literal,
      or_group
    ])
    |> optional(control_block)
    |> tag(:rule)
    |> optional(ws |> concat(control_block))
  )

  defparsecp(
    :rule_seq,
    parsec(:rule)
    |> repeat(ws |> concat(parsec(:rule)))
    |> tag(:seq)
  )

  # defparsec(:parse, parsec(:rule_seq))
  def parse(input) do
    case rule_seq(input) do
      {:ok, parsed, "", _, _, _} ->
        Validator.validate(parsed)
        {:ok, %BubbleExpr{ast: parsed}}

      {:ok, _parsed, remain, _, _, _} ->
        {:error, "Parse error near \"#{remain}\""}
    end
  end
end
