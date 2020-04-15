defmodule BubbleExpr.Validator do
  def validate([{:seq, rules}] = ast) do
    with :ok <- validate_seq(rules) do
      {:ok, ast}
    end
  end

  def validate(_) do
    {:error, "Invalid top-level AST node"}
  end

  defp validate_seq(rules) do
    Enum.reduce(rules, :ok, fn
      {:rule, rule}, :ok ->
        validate_rule(rule)
        validate_rule_control_block(rule[:control_block])

      {:control_block, block}, :ok ->
        validate_standalone_control_block(block)

      _rule, {:error, _} = error ->
        error
    end)
  end

  defp validate_rule(_rule) do
    :ok
  end

  defp validate_rule_control_block(nil) do
    :ok
  end

  defp validate_rule_control_block(_block) do
    :ok
  end

  defp validate_standalone_control_block(_block) do
    :ok
  end
end
