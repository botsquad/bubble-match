defmodule BubbleMatch do
  readme = Path.join(__DIR__, "../README.md")
  @external_resource readme
  @moduledoc File.read!(readme)

  defstruct ast: nil, q: ""

  @type t :: __MODULE__
  @type input :: [input] | String.t() | BubbleMatch.Sentence.t()
  @type match_result :: :nomatch | {:match, captures :: map()}
  @type parse_opts :: [parse_opt()]
  @type parse_opt :: {:expand, boolean()} | {:concepts_compiler, fun()}

  @doc """
  Match a given input against a BML query.
  """
  @spec match(expr :: t | String.t(), input :: input()) :: match_result()
  defdelegate match(expr, input), to: BubbleMatch.Matcher

  @doc """
  Parse a string into a BML expression.
  """
  @spec parse(expr :: String.t(), parse_opts()) :: {:ok, t()} | {:error, String.t()}
  defdelegate parse(expr, opts \\ []), to: BubbleMatch.Parser

  @doc """
  Parse a string into a BML expression, raises on error.
  """
  @spec parse!(expr :: String.t(), parse_opts()) :: t()
  defdelegate parse!(expr, opts \\ []), to: BubbleMatch.Parser
end

defimpl Inspect, for: BubbleMatch do
  import Inspect.Algebra

  def inspect(struct, _opts) do
    concat(["#BML<", struct.q, ">"])
  end
end

defimpl String.Chars, for: BubbleMatch do
  def to_string(struct) do
    struct.q
  end
end

defimpl Jason.Encoder, for: BubbleMatch do
  def encode(struct, opts) do
    Jason.Encode.string(struct.q, opts)
  end
end
