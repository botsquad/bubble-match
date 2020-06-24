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

### Basic words

`hello world`

Basic words; rules consisting of only alphanumeric characters.

Matching is done on both the lowercased, normalized, accents-removed
version of the word, and on the lemmatization of the word. The *lemma*
of a word is its base version; e.g. for verbs it is the root form (are
→ be, went → go); for nouns it is the singular form of the word.

Some languages (german, dutch, …) have *compound nouns*, that are often
written both with and without spaces or dashes.  Use a dash (`-`) to
match on such compound nouns: the rule `was-machine` matches all of
`wasmachine`, `was-machine` and `was machine`.

The apostrophe sign is also supported as part of a word, for instance
when matching something like `Martha's cookies`. In this case, the
apostrophe `'s` part is called the *particle*. For places where the
apostrophe is a verb, e.g. in `he'll do that`, you can write the verb
("will") in full in the BML, as Spacy will determine the proper
verb. In that case, the BML query would be `he will do that`, which
would also match the version with the apostrophe. Same goes for
`don't`, `he's`, etc.


### Literals

`"Literal word sequence"`

Matches a literal piece of text, which can span multiple
tokens. Matching is **case insensitive**, and also insensitive to
the presence of accented characters.


### Ignoring tokens: _

`hello _ world`

The standalone occurence of `_` matches 0-5 of any available token,
non-greedy. This can be used in places where you expect a few tokens
to occur but you don't care about the tokens.


### Matching a range of tokens

- `[1]` match exactly one token; any token
- `[2+]` match 2 or more tokens (greedy)
- `[1-3]` match 1 to 3 tokens (greedy)
- `[2+?]` match 2 or more tokens (non-greedy)
- `[1-3?]` match 1 to 3 tokens (non-greedy)

Use this when you know how many tokens you need to match, but it does
not matter what the contents of the tokens is.


### Entities

Entity tokens: `[email]` matches a token of type `:entity` with
value.kind == `email`. Entities are extracted by external means,
e.g. by an NLP NER engine like Duckling.

Entities are automatically captured under a variable with the same
name as the entity's kind.

The default list of supported entities is the following:

 - `amount_of_money` (duckling)
 - `credit_card_number` (duckling)
 - `date` (spacy)
 - `distance` (duckling)
 - `duration` (duckling)
 - `email` (duckling)
 - `event` (spacy)
 - `fac` (spacy)
 - `gpe` (spacy)
 - `language` (spacy)
 - `law` (spacy)
 - `loc` (spacy)
 - `money` (spacy)
 - `norp` (spacy)
 - `number` (duckling)
 - `ordinal` (duckling)
 - `org` (spacy)
 - `percent` (spacy)
 - `person` (spacy)
 - `phone_number` (duckling)
 - `product` (spacy)
 - `quantity` (duckling)
 - `temperature` (duckling)
 - `time` (duckling)
 - `url` (duckling)
 - `volume` (duckling)
 - `work_of_art` (spacy)

From our experience, Duckling entities work much better than Spacy
entities, and are preferred for use. Besides being more accurate, the
Duckling entities also provide more metadata, like valid UTC times
when a date is recognized.



### Regular expressions

`/regex/`

Matches the given regex against the sentence. Regexes can span
multiple tokens, thus you can match on whitespace and other token
separators. Regular expressions are **case insensitive**.

Regular expression named capture groups are also supported, to capture
a specific part of a string: `/KL(?<flight_number>\d+)/` matches
KL12345 and extracts `12345` as the `flight_number` capture.


### OR / grouping construct

Use parentheses combined with the pipe `|` character to specify an OR clause.

  - `pizza | fries | chicken` - OR-clause on the root level without
    parens, matches either token

  - `a ( a | b | c )` - use parentheses to separate OR-clauses;
    matches one token consisting of first `a`, and then `a`, `b` or
    `c`.

  - `( hi | hello )[=greeting]` matches 1 token and stores it in `greeting`

Parenthesis with | can also be used to capture a sequence of tokens together as one group:

  - `( a )[3+]` matches 3 or more token consisting of `a`


### Permutation construct

The permutation construct using pointy brackets, `<`, `>` matches the
given rules in no particular order.

 `< a b c >` matches any permutation of the sequence `a b c`; `a c b`, or `b a c`, or `c a b`, etc

An implicit `_` is inserted between all rules. So the rule `<a b>` can
also be written as `(a _ b | b _ a)`.


### Start / end sentence markers

To match the beginning of end of sentences, the following constructs can be used:

- `[Start]` Matches the start of a sentence
- `[End]` Matches the end of a sentence

> The `[Start]` and `[End]` symbols are not always the same as the
> start and end of the input string, as sometimes the user input is
> split into multiple sentences, based on the Spacy sentence
> tokenizer.


### Part-of-speech tags (word kinds)

To be able to disambiguate between word kinds, the `%` construct
matches on the POS-tag of a token:

- `%VERB` matches any verb
- `%NOUN` matches any noun

Any other [POS Spacy tags](https://spacy.io/api/annotation#pos-en) are
valid as well.


### Optionality modifier

An appended `?` makes the given rule optional (it needs to occur 0 or 1 times).


### Repetition modifier

Any rule can have a `[]` block which contains a repetition modifier
and/or a capture expression.

- `a[1]` match exactly one `a` word
- `a[2+]` match 2 or more `a`'s (greedy)
- `a[1-3]` match 1 to 3 `a`'s (greedy)
- `a[2+?]` match 2 or more `a`'s (non-greedy)
- `a[1-3?]` match 1 to 3 `a`'s (non-greedy)


### Capture modifier

`(my name is _)[=x]` stores the entire token sequence "My name is john"


### Punctuation

Punctuation is optional, and can be ignored while creating match
rules. However, punctuation tokens *are* stored in the tokenized
version of the input; in fact, multiple *tokenizations* of the input
are stored for each sentence, one without and one with with the
punctuation.

The sentence `Hello, world.` is stored both as:

- `Hello` `world`
- `Hello` `,` `world` `.`

Matching punctuation can be done by including the punctuation into `'`
literal quotes.


## Sentence tokenization

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
