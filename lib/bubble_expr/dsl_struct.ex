defmodule BubbleExpr.DslStruct do
  @moduledoc false

  defmacro __using__(struct) do
    str_fields = struct |> Keyword.keys() |> Enum.map(&to_string/1)

    quote do
      defstruct unquote(struct)

      @str_fields unquote(str_fields)

      @behaviour Access

      @impl Access
      def fetch(term, key) when key in unquote(str_fields) do
        fetch(term, String.to_atom(key))
      end

      def fetch(term, key) do
        Map.fetch(term, key)
      end

      defoverridable fetch: 2

      @impl Access
      defdelegate get_and_update(a, b, c), to: Map

      @impl Access
      defdelegate pop(a, b), to: Map
    end
  end
end
