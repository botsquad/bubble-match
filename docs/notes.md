
## Cheat sheet

Use this cheat sheet whenever you need a quick refresher on
rule-writing.  Have you reviewed the detailed descriptions of
pattern-matching yet? If not, take a look at those before using the
cheat sheet below.


> Note: BubbleMatch is inspired on the [Pullstring pattern match
> language][1]. Pullstring has been acquired by Apple in 2019 and all
> their docs are offline. This cheat sheet is copied and adapted from
> the now archived Pullstring documentation.

[1]: https://web.archive.org/web/20170920200146/http://docs.pullstring.com/docs/pattern-matching


Valid Characters: Alphanumeric characters, spaces, and apostrophes ' (when used inside a word) are valid within a rule. Any characters used as part of pattern matching syntax are valid. All other characters are only valid if using verbatim.

### Basic words

- `cookies Martha's` — matches "Those cookies are Martha's."
- `i like cookies` — matches "Oh, I really like chocolate chip cookies."

### Synonyms [NOT IMPLEMENTED YET]

- `~like` — matches all meanings for the synonym "like"

### Excluding words [NOT IMPLEMENTED YET]

Do not match certain words: !

- `!rule1 rule2` — match rule2 and not rule1

### Optional Words

Optionally match certain words or constructs by appending `?`

- `rule1? rule2` — rule1 may or may not appear, always match rule2

### Word Spacing

By default, rules can contain any number of tokens in between them. So the rule `hello world` also matches `hello cruel world`. The number of allowed tokens between two rules can be controlled with a standalone `[ ]` block.

- `rule1 [0] rule2` — no words can appear between rule1 and rule2, they are adjacent.
- `rule1 [1+] rule2` — at least 1 word between rule1 and rule2
- `rule1 [2] rule2` — exactly 2 words between rule1 and rule2
- `rule1 [2-5] rule2` — between 2 and 5 words between rule1 and rule2
- `rule1 [2-3=LABEL] rule2` — between 2 and 3 words between rule1 and rule2, store the captured words between rule1 and rule2 in LABEL

### Verbatim

Match parts of the original sentence exactly by using double quotes around a rule: `"…"`

- `"rule1"` — rule1 must be matched exactly, with no NLP processing. Can span word tokens (can contain spaces)

### Start / End

Make sure rule words are first and/or last: [Start], [End]

- `[Start] rule1` — rule1 must be the first word
- `rule1 [End]` — rule1 must be the last word

### Numbers

Match any number: `[number]`

- [number] — match any number

Implemented using the Duckling `number` entity.

**Number ranges are not implemented yet**:

- [number=50+] — match any number greater than or equal to 50
- [number=1-100] — match any number from 1 to 100

### Unordered Matching

Allow rule words in any order: `< >`

- `< rule1, rule2, rule3 >` — all rule words MUST occur, but may occur in any order

### Matching Optional Words

Specify the number of matches from a set of rules in any order: `( | )`

- `( rule1 | rule2 )` — match rule1 or rule2

### Repeating constructs

Storing User Input: Remember the actual input entered by the user or the number of matches

- `( hello world )[=greeting]` - stores the greeting in the `greeting` slot. All words between `hello` and `world` are captured as well.
- `my name is [1-3=name]` - stores the user name (consisting of 1 to 3 tokens) in the `name` slot.

Any rule construct can contain the `[]` modifier to control the number
of occurrences, and to store it in a variable:

Repeating a construct multiple times:

`hello[1+]` matches `hello` but also `hello hello hello`

### Combining Rules

Almost any of the above pattern matching rules can be combined.

- `rule1 [1+] !rule2 rule3` — at least 1 word occurs between rule1 and rule3, and that 1 word cannot be rule2
- `( rule1 [0] rule2 rule3 )` — no words can occur between rule1 and rule2
- `< rule1 ( rule2 | rule3 ) >` — rule1 must be matched, at least 1 of rule2 and/or rule3 must occur
- `rule1 rule2? "rule3"` — rule1 must be matched, rule2 may or may not be matched, and rule3 must be matched verbatim


## Definition

### Base version requirements

- word normalization (lemmatization)
- ( a | b ) to indicate 'or'; grouping
- "literal" (still case insensitive)
- '+' to indicate adjacent rules: my + name + is; no words in between
- ? appended = optional rule; same as [0-1] appended
- [control instructions]
  - [=store_as_name] store last captured rule
  - [Start] start of sentence (standalone)
  - [End] end of sentence (standalone)
  - [0-10] standalone match N words
  - [0-10] appended; match 1-10 rules
  - [1+] appended; match 1 or more
- /.../ regex token
- < a, b > indicates order-independent sequence


### Extended version

- polarity filter (language specific!)
- @ to indicate rule composition
  my email is /[a-z]@[a-z].com/[=email]
- duckling
  [Email] [AmountOfMoney] [CreditCardNumber] [Distance] [Numeral] etc.




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
