## Bubblescript Matching Language (BML)

[![Build status](https://travis-ci.com/botsquad/bubble-match.svg?branch=master)](https://travis-ci.com/github/botsquad/bubble-match)
[![Hex pm](http://img.shields.io/hexpm/v/bubble_match.svg?style=flat)](https://hex.pm/packages/bubble_match)

BML is a rule language for matching natural language against a rule
base. Think of it as regular expressions for *sentences*. Whereas
regular expressions work on individual characters, BML rules primarily
work on a tokenized representation of the string.

BML ships with a builtin string tokenizer, but for production usage
you should look into using a language-specific tokenizer, e.g. to use
the output of [Spacy's Doc.to_json][spacy] function.

[spacy]: https://spacy.io/api/doc#to_json

> This project is still in development, and as such, the BML syntax is still subject to change.

The full documentation on the BML syntax and the API reference is
available [on hexdocs.pm](https://hexdocs.pm/bubble_match/).  To try
out BML, [check out the demo
environment](https://bml.botsquad.com/), powered by Phoenix
Liveview.


## Examples

Matching basic sequences of words:

| Match string  | Example           | Matches? |
|---------------|-------------------|----------|
| `hello world` | Hello, world!     | **yes**  |
| `hello world` | Well hello world  | **yes**  |
| `hello world` | hello there world | no       |
| `hello world` | world hello       | no       |


Matching regular expressions:

| Match string | Example | Matches? |
|--------------|---------|----------|
| `/[a-z]+/`   | abcd    | **yes**  |


Match entities, with the help of Spacy and Duckling preprocessing and
tokenizing the input:

| Match string | Matches                         | Does not match  |
|--------------|---------------------------------|-----------------|
| `[person]`   | George Baker                    | Hello world     |
| `[time]`     | I walked to the store yesterday | My name is John |


## Rules overview

The match syntax is composed of adjacent and optionally nested,
rules. Each individual has the following syntax:

- Basic words; only alphanumeric characters and the quote characters
  - matching is done on both the lowercased, normalized version of the
    word, and on the lemmatization of the word.

  - use a dash (`-`) to match on compound nouns: `was-machine` matches
    all of `wasmachine`, `was-machine` and `was machine`.

- `"Literal word sequence"`
  - Matches a literal piece of text, possibly spread out over multiple tokens.

- `_` without any range specifier, matches 0-5 of any available token, greedy.

- Stand-alone range specifier
  - `[1]` match exactly one token; any token
  - `[2+]` match 2 or more tokens (greedy)
  - `[1-3]` match 1 to 3 tokens (greedy)
  - `[2+?]` match 2 or more tokens (non-greedy)
  - `[1-3?]` match 1 to 3 tokens (non-greedy)

- Entity tokens: `[email]` matches a token of type `:entity` with
  value.kind == `email`. Entities are extracted by external means,
  e.g. by an NLP NER engine like Duckling.

  Entities are automatically captured under a variable with the same
  name as the entity's kind.

- Regex tokens: `[/regex/]` matches the given regex against the raw text in the token

- OR / grouping construct

  - `pizza | fries | chicken` - OR-clause on the root level without
    parens, matches either token

  - `a ( a | b | c )` - use parentheses to separate OR-clauses;
    matches one token consisting of first `a`, and then `a`, `b` or
    `c`.

  - `( a )[3+]` matches 3 or more token consisting of `a`
  - `( hi | hello )[=greeting]` matches 1 token and stores it in `greeting`

- Permutation construct
 - `< a b c >` matches any permutation of the sequence `a b c`; `a c b`, or `b a c`, or `c a b`, etc

- Start / end sentence markers
- `[Start]` Matches the start of a sentence
- `[End]` Matches the end of a sentence

- Word collections ("concepts")
  - `@food` matches any token in the `food` collection.
  - `@food.subcat` matches any token in the given subcategory.

  Concept compilation is done as part of the parse phase; the concepts
  compiler must must return an `{m, f, a}` triple. In runtime, this
  MFA is called while matching, and thus, it must be a fast function.

- Part-of-speech tags (word kinds), e.g.
  - `%VERB` matches any verb
  - `%NOUN` matches any noun
  - Any other POS Spacy tags are valid as well


### Rule modifiers

Any rule can have a `[]` block which contains a repetition modifier
and/or a capture expression.

Entity blocks are automatically captured as the entity kind.

### Sentences

The expression matching works on a per-sentence basis; the idea is
that it does not make sense to create expressions that span over
sentences.

The builtin sentence tokenizer (`BubbleMatch.Sentence.Tokenizer`) does
**not** have the concept of sentences, and thus treats each input as a
single sentence, even in the existence of periods in the input.

However, the prefered way of using this library is by running the
input through an NLP preprocessor like Spacy, which does tokenize an
input into individual sentences.


## Sigil

For use within Elixir, it is possible to use a `~m` sigil which parses
the given BML query on compile-time:

```elixir
defmodule MyModule do
  use BubbleMatch.Sigil

  def greeting?(input) do
    BubbleMatch.match(~m"hello | hi | howdy", input) != :nomatch
  end
end
```


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `bubble_match` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bubble_match, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/bubble_match](https://hexdocs.pm/bubble_match).
