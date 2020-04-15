# BubbleExpr

NLP rule language for matching natural language against a rule base.

## Definition

### Base version

- word normalization (lemmatization)
- ( a | b ) to indicate 'or'; grouping
- "literal" (still case insensitive)
- '+' to indicate adjacent rules: my + name + is; no words inbetween
- ? appended = optional rule; same as [0-1] appended
- [control instructions]
  - [=store_as_name] store last captured rule
  - [Start] start of sentence (standalone)
  - [End] end of sentence (standalone)
  - [0-10] standalone match N words
  - [0-10] appended; match 1-10 rules
  - [0-] appended; match 0 or more

### Extended version

- polarity filter (language specific!)
- @ to indicate rule composition
- < a, b > indicates order-independent sequence
- /.../ regex
  my email is /[a-z]@[a-z].com/[=email]
- duckling
  [Email] [AmountOfMoney] [CreditCardNumber] [Distance] [Numeral] etc.


## Examples


## Inspiration

### pullstring

- polarity filter (do not match negative stmts)
- put * (any word) operator by default between all words
- alternatives ( alternative | other )
- all required but order independent: < a, b, c >
- wordnet-based synonyms (~like)
- negation (!word)
- optional rules (?rule)
- literal sequences "San Francisco" (verbatim)
- control nr of words between rules [0] [1] [1-10]
- match start / end of sentence ([Start] [End])

- add flags / modifiers to rules (to store information etc)

### spacy

- word normalization (lemmatization)
- named entities (overlap w/ duckling?)

### chatscript

- statement / question detection
- composable user-defined concepts: ~food ( ~meat ~dessert lasagna ~vegetables ~fruit )
- can use wordnet ontologies
- "canonical forms" of words

### duckling

Use entity detection like
- email, date, number, etc.



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
