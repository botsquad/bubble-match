defmodule BubbleMatch.DslStruct do
  @moduledoc """
  A "DSL Struct" is a struct which can be exposed in Bubblescript.

  Most notable are intent, message, attachment, location, event.
  """

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
      def get_and_update(term, key, fun) when key in unquote(str_fields) do
        get_and_update(term, String.to_atom(key), fun)
      end

      def get_and_update(term, key, fun), do: Map.get_and_update(term, key, fun)

      defoverridable get_and_update: 3

      @impl Access
      def pop(term, key) when key in unquote(str_fields) do
        pop(term, String.to_atom(key))
      end

      def pop(term, key), do: Map.pop(term, key)

      defoverridable pop: 2

      def __jason_encode__(struct, opts, only) do
        struct
        |> Map.keys()
        |> Enum.reject(&(&1 != "__struct__" && (is_list(only) && &1 in only)))
        |> Enum.map(fn k -> {Atom.to_string(k), Map.get(struct, k)} end)
        |> Map.new()
        |> Jason.Encode.map(opts)
      end
    end
  end

  defmacro jason_derive(mod, only \\ nil) do
    quote do
      defimpl Jason.Encoder, for: unquote(mod) do
        def encode(struct, opts) do
          unquote(mod).__jason_encode__(struct, opts, unquote(only))
        end
      end
    end
  end

  def instantiate_structs(%{"__struct__" => mod} = struct) do
    struct =
      struct
      |> Enum.map(fn {k, v} ->
        {k, instantiate_structs(v)}
      end)
      |> Map.new()

    mod = String.to_atom(mod)
    orig = apply(mod, :__struct__, [])

    Map.keys(orig)
    |> Enum.map(fn k -> {k, Map.get(struct, Atom.to_string(k)) || Map.get(orig, k)} end)
    |> Map.new()
    |> Map.put(:__struct__, mod)
  end

  def instantiate_structs(%{__struct__: _} = struct) do
    struct
  end

  def instantiate_structs(%{} = map) do
    map
    |> Enum.map(fn {k, v} ->
      {k, instantiate_structs(v)}
    end)
    |> Map.new()
  end

  def instantiate_structs(list) when is_list(list) do
    Enum.map(list, &instantiate_structs/1)
  end

  def instantiate_structs(value), do: value

  def struct_from_map(struct, input) do
    Enum.reduce(Map.to_list(struct), struct, fn {k, _}, acc ->
      case Map.fetch(input, Atom.to_string(k)) do
        {:ok, v} -> %{acc | k => v}
        :error -> acc
      end
    end)
  end
end
