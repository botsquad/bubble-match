defmodule BubbleExpr.Sentence do
  defstruct text: nil, tokenizations: []
  #
  alias BubbleExpr.Sentence.Tokenizer
  alias BubbleExpr.Token

  alias __MODULE__, as: M

  def naive_tokenize("") do
    %M{text: "", tokenizations: [[]]}
  end

  def naive_tokenize(input) do
    tokens = Tokenizer.tokenize(input)
    %M{text: input, tokenizations: [tokens]}
  end

  @doc """
  Adds an alternative tokenization by replacing tokens
  """
  def add_tokenization(%M{} = m, new_tokens) do
    # for each existing tokenization, find the start / end index to be replaced

    # start: find the tokens where
    # -

    # {start_tokens, _} = Enum.split(m.tokens, start_index)
    # {_, end_tokens} = Enum.split(m.tokens, end_index)
    # m = %M{m | tokens: start_tokens ++ new_tokens ++ end_tokens}

    # # ensure we are still a valid sentence
    # if m.text != Enum.join(Enum.map(m.tokens, & &1.raw), " ") do
    #   raise RuntimeError, "replace_tokens differ from original sentence"
    # end

    m
  end

  def from_spacy(%{"text" => text, "tokens" => tokens, "ents" => ents}) do
    %M{text: text, tokenizations: [Enum.map(tokens, &Token.from_spacy/1)]}
  end
end
