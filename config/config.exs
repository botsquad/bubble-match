use Mix.Config

# List the valid entities. They default to the combination of the
# builtin Spacy entities,
# https://spacy.io/api/annotation#named-entities and the Duckling
# entitites, https://github.com/facebook/duckling. Names are
# lowercased and camelized.
config :bubble_match, valid_entities: ~w(
  amount_of_money
  credit_card_number
  distance
  duration
  email
  ordinal
  number
  phone_number
  quantity
  temperature
  time
  url
  volume
  person
  norp
  fac
  org
  gpe
  loc
  product
  event
  work_of_art
  law
  language
  date
  time
  percent
  money
  quantity
)
