defmodule BubbleMatch.Entity do
  use BubbleLib.DslStruct,
    kind: nil,
    provider: nil,
    value: nil,
    raw: nil,
    extra: %{}

  alias __MODULE__, as: M

  def new(provider, kind, value, raw, extra \\ %{}) do
    %M{provider: provider, kind: kind, value: value, raw: raw, extra: extra}
  end
end

defimpl String.Chars, for: BubbleMatch.Entity do
  def to_string(%BubbleMatch.Entity{value: value}) do
    Kernel.to_string(value)
  end
end

require BubbleLib.DslStruct
BubbleLib.DslStruct.jason_derive(BubbleMatch.Entity)
