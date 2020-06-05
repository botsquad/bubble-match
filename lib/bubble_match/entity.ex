defmodule BubbleMatch.Entity do
  use BubbleMatch.DslStruct,
    kind: nil,
    provider: nil,
    value: nil

  alias __MODULE__, as: M

  def new(provider, kind, value) do
    %M{provider: provider, kind: kind, value: value}
  end
end

defimpl String.Chars, for: BubbleMatch.Entity do
  def to_string(%BubbleMatch.Entity{value: value}), do: Kernel.to_string(value)
end
