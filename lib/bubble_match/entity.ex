defmodule BubbleMatch.Entity do
  use BubbleLib.DslStruct,
    kind: nil,
    provider: nil,
    value: nil

  alias __MODULE__, as: M

  def new(provider, kind, value) do
    %M{provider: provider, kind: kind, value: value}
  end
end

defimpl String.Chars, for: BubbleMatch.Entity do
  def to_string(%BubbleMatch.Entity{value: value}) do
    case value do
      %{"value" => v} -> v
      v -> v
    end
    |> Kernel.to_string()
  end
end

require BubbleLib.DslStruct
BubbleLib.DslStruct.jason_derive(BubbleMatch.Entity)
