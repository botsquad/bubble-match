defmodule BubbleMatch.MixProject do
  use Mix.Project

  def project do
    [
      app: :bubble_match,
      version: File.read!("VERSION"),
      elixir: "~> 1.9",
      description: description(),
      package: package(),
      source_url: "https://github.com/botsquad/bubble-match",
      homepage_url: "https://github.com/botsquad/bubble-match",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [main: "BubbleMatch"]
    ]
  end

  defp description do
    "A matching language for matching queries against token-based natural language input. Like Regular Expressions, but for for natural language."
  end

  defp package do
    %{
      files: ["lib", "mix.exs", "*.md", "LICENSE", "VERSION"],
      maintainers: ["Arjan Scherpenisse"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/botsquad/bubble-match"}
    }
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
      {:bubble_lib, "~> 1.0"},
      {:nimble_parsec, "~> 0.5.3"},
      {:inflex, "~> 2.0"},
      {:jason, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:stream_data, "~> 0.1", only: :test}
    ]
  end
end
