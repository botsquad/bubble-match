defmodule BubbleMatch.Sigil do
  @doc """
  Define the `~m` sigil for compile-time parsing of BML expressions.

  For use within Elixir it is possible to use a `~m` sigil which
  parses the given BML query on compile-time:

  ```elixir
  defmodule MyModule do
    use BubbleMatch.Sigil

    def greeting?(input) do
      BubbleMatch.match(~m"hello | hi | howdy", input) != :nomatch
    end
  end
  ```

  """

  defmacro sigil_m({:<<>>, _, [expr]}, []) do
    Macro.escape(BubbleMatch.parse!(expr))
  end

  defmacro __using__(_args) do
    quote do
      require unquote(__MODULE__)
      import unquote(__MODULE__), only: [sigil_m: 2]
    end
  end
end
