defmodule BubbleMatch.Unidekode do
  @moduledoc """
  Documentation for Unidekode.
  """

  @doc """
  Transliterate Unicode characters to US-ASCII.

  ## Examples

      iex> BubbleMatch.Unidekode.to_ascii("código")
      "codigo"

      iex> BubbleMatch.Unidekode.to_ascii("código😀")
      "codigo"

      iex> BubbleMatch.Unidekode.to_ascii('código')
      'codigo'

      iex> BubbleMatch.Unidekode.to_ascii('código℗')
      'codigo'
  """
  @spec to_ascii(binary() | charlist()) :: binary() | charlist()
  def to_ascii(string), do: to_ascii(string, <<>>)

  defp to_ascii(<<>>, ascii), do: ascii
  defp to_ascii([], ascii), do: to_charlist(ascii)

  defp to_ascii(<<b::utf8, rest::binary>>, ascii) do
    to_ascii(rest, <<ascii::binary, transliterate(b)::binary>>)
  end

  defp to_ascii([b | rest], ascii) do
    to_ascii(rest, <<ascii::binary, transliterate(b)::binary>>)
  end

  @doc """
  Remove accented characters from the string, but keeping special characters like emoji

  ## Examples

      iex> BubbleMatch.Unidekode.drop_accented("código")
      "codigo"

      iex> BubbleMatch.Unidekode.drop_accented("código 👍")
      "codigo 👍"
  """
  @spec drop_accented(binary()) :: binary()
  def drop_accented(string), do: drop_accented(string, <<>>)

  defp drop_accented(<<>>, output), do: output

  defp drop_accented(<<b::utf8, rest::binary>>, output) do
    case transliterate(b) do
      <<>> ->
        drop_accented(rest, <<output::binary, b::utf8>>)

      t ->
        drop_accented(rest, <<output::binary, t::binary>>)
    end
  end

  @matches Path.join(__DIR__, "UnicodeData.txt")
           |> File.stream!([:read], :line)
           |> Stream.filter(&String.contains?(&1, "WITH"))
           |> Stream.map(&:string.split(&1, ";", :all))
           |> Stream.flat_map(fn
             [
               capital_match,
               <<"LATIN CAPITAL LETTER ", letter::binary-size(1), _::binary>>,
               _,
               _,
               _,
               _,
               _,
               _,
               _,
               _,
               _,
               _,
               _,
               small_match,
               _
             ] ->
               [
                 {String.to_integer(capital_match, 16), letter},
                 {String.to_integer(small_match, 16), String.downcase(letter)}
               ]

             _ ->
               []
           end)
           |> Stream.concat(
             for x <-
                   '!"#%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~\s\t\n',
                 do: {x, <<x>>}
           )
           |> Enum.uniq()

  @doc !"""
       List all the matches generated from the `UnicodeData.txt`.

       ## Examples

           iex> Unidekode.matches()
           [{33, "!"}, ...]
       """
  @spec matches() :: [{integer(), binary()}, ...]
  def matches(), do: @matches

  for {match, result} <- @matches do
    defp transliterate(unquote(match)), do: unquote(result)
  end

  defp transliterate(_), do: <<>>
end
