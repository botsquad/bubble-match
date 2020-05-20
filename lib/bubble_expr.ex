defmodule BubbleExpr do
  readme = Path.join(__DIR__, "../README.md")
  @external_resource readme
  @moduledoc File.read!(readme)

  defstruct ast: nil

  @type t :: __MODULE__
  @type input :: [input] | String.t() | BubbleExpr.Sentence.t()
  @type match_result :: :nomatch | {:match, captures :: map()}
  @type parse_opts :: [parse_opt()]
  @type parse_opt :: {:expand, boolean()} | {:concepts_compiler, fun()}

  @doc """
  Match a given input against a BML query.
  """
  @spec match(expr :: t | String.t(), input :: input()) :: match_result()
  defdelegate match(expr, input), to: BubbleExpr.Matcher

  @doc """
  Parse a string into a BML expression.
  """
  @spec parse(expr :: String.t(), parse_opts()) :: {:ok, t()} | {:error, String.t()}
  defdelegate parse(expr, opts \\ []), to: BubbleExpr.Parser

  @doc """
  Parse a string into a BML expression, raises on error.
  """
  @spec parse!(expr :: String.t(), parse_opts()) :: t()
  defdelegate parse!(expr, opts \\ []), to: BubbleExpr.Parser
end
