# BubbleExpr

NLP rule language for matching natural language against a rule base.

**Warning: this project is currently heavily in development. Its syntax and API might change at any time**

[Check out the demo environment](http://expr-ninja.apps.botsqd.com/) powered by Phoenix Liveview.


## Examples

Match basic words, including optional words in between:

| Match string  | Matches            | Does not match |
|---------------|--------------------|----------------|
| `hello world` | Hello, world!      | World hello    |
|               | Hello there, world |                |
|               | Well hello world   |                |

Match regular expressions

| Match string | Matches | Does not match |
|--------------|---------|----------------|
| `/[a-z]+/`   | abcd    | LALA           |


Match entities, with the help of Spacy and Duckling preprocessing and
tokenizing the input:

| Match string | Matches      | Does not match |
|--------------|--------------|----------------|
| `[PERSON]`   | George Baker | Hello world    |


## Rules overview

The match syntax is made up by rules. Each individual has the following syntax:

- Basic words; only alphanumeric characters and the quote characters
  - matching is done on both the lowercased, normalized version of the
    word, and on the lemmatization of the word.

- `"Literal word sequence"`
  - Matches a literal piece of text, possibly spread out over multiple tokens.

- `_` without any range specifier, matches 1-5 of any available token, greedy.

- Stand-alone range specifier
  - `[1]` match exactly one token; any token
  - `[2+]` match 2 or more tokens (greedy)
  - `[1-3]` match 1 to 3 tokens (greedy)

- Entity tokens: `[email]` matches a token of type `:entity` with value.kind == `email`

- Regex tokens: `[/regex/]` matches the given regex against the raw text in the token

- OR / grouping construct
  - `( a | b | c )` matches one token consisting of `a`, `b` or `c`
  - `( a )[3+]` matches 3 or more token consisting of `a`
  - `( hi | hello )[=greeting]` matches 1 token and stores it in `greeting`

- Permutation construct
 - `< a b c >` matches any permutation of the sequence `a b c`; `a c b`, or `b a c`, or `c a b`, etc

- Start / end sentence markers
- `[Start]` Matches the start of a sentence
- `[End]` Matches the end of a sentence

   Note that sentences are always matched individually.

- Word collections ("concepts")
  - `~food` matches any token in the `food` collection. Collection resolution is done at expression parse time.


### Rule modifiers

Any rule can have a `[]` block which contains a repetition modifier
and/or a capture expression.

Entity blocks are automatically captured as the entity kind.





## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `bubble_expr` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bubble_expr, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/bubble_expr](https://hexdocs.pm/bubble_expr).
