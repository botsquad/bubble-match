defmodule BubbleMatch.MixProject do
  use Mix.Project

  def project do
    [
      app: :bubble_match,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [main: "BubbleMatch"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 0.5"},
      {:inflex, "~> 2.0"},
      {:jason, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:stream_data, "~> 0.1", only: :test}
    ]
  end
end
