defmodule BubbleMatch.SentenceTest do
  use ExUnit.Case

  alias BubbleMatch.{Entity, Sentence}

  @spacy_json """
              {"ents":[{"end":27,"label":"PERSON","start":21}],"sents":[{"end":9,"start":0},{"end":27,"start":10}],"text":"Hi there. My name is George","tokens":[{"dep":"ROOT","end":2,"head":0,"id":0,"lemma":"hi","norm":"hi","pos":"INTJ","start":0,"string":"Hi ","tag":"UH"},{"dep":"advmod","end":8,"head":0,"id":1,"lemma":"there","norm":"there","pos":"ADV","start":3,"string":"there","tag":"RB"},{"dep":"punct","end":9,"head":0,"id":2,"lemma":".","norm":".","pos":"PUNCT","start":8,"string":". ","tag":"."},{"dep":"poss","end":12,"head":4,"id":3,"lemma":"-PRON-","norm":"my","pos":"DET","start":10,"string":"My ","tag":"PRP$"},{"dep":"nsubj","end":17,"head":5,"id":4,"lemma":"name","norm":"name","pos":"NOUN","start":13,"string":"name ","tag":"NN"},{"dep":"ROOT","end":20,"head":5,"id":5,"lemma":"be","norm":"is","pos":"AUX","start":18,"string":"is ","tag":"VBZ"},{"dep":"attr","end":27,"head":5,"id":6,"lemma":"George","norm":"george","pos":"PROPN","start":21,"string":"George","tag":"NNP"}]}
              """
              |> Jason.decode!()

  test "from_spacy" do
    hithere = Sentence.from_spacy(@spacy_json)

    assert [with_ents_no_punct, _with_ents, raw_tokens_no_punct, _raw_tokens] =
             hithere.tokenizations

    assert ~w(hi there my name is george) == Enum.map(raw_tokens_no_punct, & &1.value["norm"])
    assert ~w(spacy spacy spacy spacy spacy entity)a == Enum.map(with_ents_no_punct, & &1.type)

    assert [_, _, _, _, _, %{value: %Entity{value: "George"}}] = with_ents_no_punct
  end

  test "match from spacy" do
    sent = Sentence.from_spacy(@spacy_json)

    assert {:match, _} = BubbleMatch.Matcher.match("%NOUN", sent)

    assert {:match, _} = BubbleMatch.Matcher.match("my name is", sent)
    assert :nomatch = BubbleMatch.Matcher.match("my brother is", sent)

    assert {:match, m} = BubbleMatch.Matcher.match("[person]", [sent])

    assert [%{value: %{kind: "person", value: "George"}}] = m["person"]
  end

  @hello_world_json """
                    {"text": "Hello, w\u00f3rld", "ents": [], "sents": [{"start": 0, "end": 12}], "tokens": [{"id": 0, "start": 0, "end": 5, "pos": "INTJ", "tag": "UH", "dep": "ROOT", "head": 0, "string": "Hello", "lemma": "hello", "norm": "hello"}, {"id": 1, "start": 5, "end": 6, "pos": "PUNCT", "tag": ",", "dep": "punct", "head": 2, "string": ", ", "lemma": ",", "norm": ","}, {"id": 2, "start": 7, "end": 12, "pos": "NOUN", "tag": "NN", "dep": "npadvmod", "head": 0, "string": "w\u00f3rld", "lemma": "w\u00f3rld", "norm": "w\u00f3rld"}]}
                    """
                    |> Jason.decode!()

  test "spacy ignore punctuation, strip accents" do
    sent = Sentence.from_spacy(@hello_world_json)

    assert {:match, _} = BubbleMatch.Matcher.match("hello world", sent)
  end

  @duckling_json """
                 [{"body":"the day after tomorrow","start":15,"value":{"values":[{"value":"2020-04-30T00:00:00.000+02:00","grain":"day","type":"value"}],"value":"2020-04-30T00:00:00.000+02:00","grain":"day","type":"value"},"end":37,"dim":"time","latent":false},{"body":"10 miles","start":39,"value":{"value":10,"type":"value","unit":"mile"},"end":47,"dim":"distance","latent":false}]
                 """
                 |> Jason.decode!()

  test "add duckling entities" do
    sentence =
      Sentence.naive_tokenize("My birthday is the day after tomorrow, 10 miles away")
      |> Sentence.add_duckling_entities(@duckling_json)

    assert [with_ents, with_ents_punct | _] = sentence.tokenizations

    assert [
             %{value: "my"},
             %{value: "birthday"},
             %{value: "is"},
             %{
               type: :entity,
               raw: "the day after tomorrow",
               value: %Entity{kind: "time", value: "2020-04" <> _, extra: %{"grain" => "day"}}
             },
             %{
               type: :entity,
               raw: "10 miles",
               value: %Entity{kind: "distance", value: 10, extra: %{"unit" => "mile"}}
             },
             _awai
           ] = with_ents

    assert [
             %{value: "my"},
             %{value: "birthday"},
             %{value: "is"},
             %{
               type: :entity,
               value: %Entity{kind: "time", value: "2020-04" <> _, extra: %{"grain" => "day"}}
             },
             %{value: ","},
             %{
               type: :entity,
               value: %Entity{kind: "distance", value: 10, extra: %{"unit" => "mile"}}
             },
             _awai
           ] = with_ents_punct
  end

  test "encoding" do
    hithere = Sentence.from_spacy(@spacy_json)
    assert {:ok, encoded} = Jason.encode(hithere)
    assert "{\"__struct__\":" <> _ = encoded
  end

  test "access; to_string" do
    hithere = Sentence.from_spacy(@spacy_json)
    assert "Hi there. My name is George" == hithere["text"]
    assert "Hi there. My name is George" == hithere[:text]
    assert "Hi there. My name is George" == to_string(hithere)
  end

  @time_duckling """
                   [{"body":"9 p.m.","start":0,"value":{"values":[{"value":"2020-06-10T21:00:00.000+02:00","grain":"hour","type":"value"},{"value":"2020-06-11T21:00:00.000+02:00","grain":"hour","type":"value"},{"value":"2020-06-12T21:00:00.000+02:00","grain":"hour","type":"value"}],"value":"2020-06-10T21:00:00.000+02:00","grain":"hour","type":"value"},"end":6,"dim":"time","latent":false}]
                 """
                 |> Jason.decode!()

  @time_spacy """
              {"text":"9 p.m.","ents":[],"sents":[{"start":0,"end":1},{"start":2,"end":6}],"tokens":[{"id":0,"start":0,"end":1,"pos":"NUM","tag":"CD","dep":"ROOT","head":0,"string":"9 ","lemma":"9","norm":"9"},{"id":1,"start":2,"end":6,"pos":"NOUN","tag":"NN","dep":"ROOT","head":1,"string":"p.m.","lemma":"p.m.","norm":"p.m."}]}
              """
              |> Jason.decode!()

  test "overlapping duckling entities" do
    a = Sentence.from_spacy(@time_spacy)

    assert [_] = a.tokenizations
    a = a |> Sentence.add_duckling_entities(@time_duckling)
    assert [with_ents, _raw_tokens] = a.tokenizations
    assert List.first(with_ents).value.kind == "time"
  end

  @spacy_json """
              {"detected_language": null, "detected_language_prob": 0.12450417876243591, "ents": [], "nlp_language": "en", "sents": [{"end": 8, "start": 0}], "text": "Thanks 👍", "tokens": [{"dep": "compound", "end": 6, "head": 1, "id": 0, "lemma": "thanks", "norm": "thanks", "pos": "INTJ", "start": 0, "string": "Thanks ", "tag": "UH"}, {"dep": "ROOT", "end": 8, "head": 1, "id": 1, "lemma": "👍", "norm": "👍", "pos": "PROPN", "start": 7, "string": "👍", "tag": "NNP"}]}
              """
              |> Jason.decode!()

  test "Emoji can be matched" do
    s = %{tokenizations: [_tok, with_punct]} = Sentence.from_spacy(@spacy_json)

    assert [_, %{value: %{"pos" => "EMOJI"}}] = with_punct

    assert {:match, _} = BubbleMatch.Matcher.match("%EMOJI", s)
    assert {:match, _} = BubbleMatch.Matcher.match("%EMOJI [End]", s)

    assert {:match, _} = BubbleMatch.Matcher.match("[Start] thanks [End]", s)
    assert {:match, _} = BubbleMatch.Matcher.match("[Start] thanks %EMOJI [End]", s)

    assert {:match, _} = BubbleMatch.Matcher.match("'👍'", s)
  end

  @spacy_json2 """
               {"detected_language": null, "detected_language_prob": 0.12450417876243591, "ents": [], "nlp_language": "en", "sents": [{"end": 8, "start": 0}], "text": "Thanks 8", "tokens": [{"dep": "compound", "end": 6, "head": 1, "id": 0, "lemma": "thanks", "norm": "thanks", "pos": "INTJ", "start": 0, "string": "Thanks ", "tag": "UH"}, {"dep": "ROOT", "end": 8, "head": 1, "id": 1, "lemma": "8", "norm": "8", "pos": "PROPN", "start": 7, "string": "8", "tag": "NNP"}]}
               """
               |> Jason.decode!()

  test "Emoji false positive" do
    s = %{tokenizations: [_]} = Sentence.from_spacy(@spacy_json2)

    assert :nomatch = BubbleMatch.Matcher.match("%EMOJI", s)
    assert :nomatch = BubbleMatch.Matcher.match("%EMOJI [End]", s)

    assert :nomatch = BubbleMatch.Matcher.match("[Start] thanks [End]", s)
    assert :nomatch = BubbleMatch.Matcher.match("[Start] thanks %EMOJI [End]", s)
  end

  @spacy_json """
              {"detected_language": "nl", "detected_language_prob": 0.6659534573554993, "ents": [{"end": 26, "label": "CARDINAL", "start": 24}], "nlp_language": "nl", "sents": [{"end": 23, "start": 0}, {"end": 26, "start": 24}], "text": "Bosboom Toussaintstraat 23", "tokens": [{"dep": "ROOT", "end": 7, "head": 0, "id": 0, "lemma": "bosboom", "morph": "", "norm": "bosboom", "pos": "PROPN", "start": 0, "tag": "SPEC|deeleigen", "text": "Bosboom"}, {"dep": "flat", "end": 23, "head": 0, "id": 1, "lemma": "toussaintstraat", "morph": "", "norm": "toussaintstraat", "pos": "PROPN", "start": 8, "tag": "SPEC|deeleigen", "text": "Toussaintstraat"}, {"dep": "ROOT", "end": 26, "head": 2, "id": 2, "lemma": "23", "morph": "", "norm": "23", "pos": "NUM", "start": 24, "tag": "TW|hoofd|vrij", "text": "23"}]}
              """
              |> Jason.decode!()

  test "spacy 3.2" do
    s = Sentence.from_spacy(@spacy_json)

    assert {:match, _} = BubbleMatch.Matcher.match("/straat|weg/ %NUM", s)
  end

  test "match against spacy" do
    s = Sentence.from_spacy(@spacy_json)

    re = "/\\d{1}/[=num]"

    assert {:match, %{"num" => [%{raw: "23 "}]}} = BubbleMatch.Matcher.match(re, s)
  end

  @spacy_json """
              {"detected_language": null, "detected_language_prob": 0.12450417876243591, "ents": [], "nlp_language": "en", "sents": [], "text": "", "tokens": []}
              """
              |> Jason.decode!()

  test "empty sent" do
    s = Sentence.from_spacy(@spacy_json)
    assert s.text == ""
  end

  @spacy_json """
              {"detected_language": "nl", "detected_language_prob": 0.5985481142997742, "ents": [{"end": 5, "label": "DATE", "start": 1}], "nlp_language": "nl", "sents": [{"end": 5, "start": 0}], "text": " juni", "tokens": [{"dep": "_sp", "end": 1, "head": 0, "id": 0, "lemma": " ", "morph": "", "norm": " ", "pos": "SPACE", "start": 0, "tag": "_SP", "text": " "}, {"dep": "appos", "end": 5, "head": 0, "id": 1, "lemma": "juni", "morph": "Gender=Com|Number=Sing", "norm": "juni", "pos": "PROPN", "start": 1, "tag": "N|eigen|ev|basis|zijd|stan", "text": "juni"}]}

              """
              |> Jason.decode!()

  test "sent w/ space" do
    s = Sentence.from_spacy(@spacy_json)

    assert :nomatch = BubbleMatch.Matcher.match("'foo'", s)
    assert {:match, _} = BubbleMatch.Matcher.match("'juni'", s)
  end

  @spacy_json """
              {"text":"صباح الخير","ents":[{"start":0,"end":4,"label":"ORG"}],"sents":[{"start":0,"end":10}],"tokens":[{"id":0,"start":0,"end":4,"tag":"JJ","pos":"ADJ","morph":"Degree=Pos","lemma":"صباح","dep":"amod","head":1,"text":"صباح","norm":"صباح"},{"id":1,"start":5,"end":10,"tag":"NN","pos":"NOUN","morph":"Number=Sing","lemma":"الخير","dep":"ROOT","head":1,"text":"الخير","norm":"الخير"}],"detected_language":"ar","detected_language_prob":0.9709909558296204,"nlp_language":"en"}
              """
              |> Jason.decode!()

  test "sent arabic" do
    s = Sentence.from_spacy(@spacy_json)

    assert [%{value: %{"lemma" => "صباح"}}, %{value: %{"lemma" => "الخير"}}] =
             List.last(s.tokenizations)
  end

  @spacy_json """
              {"detected_language": "nl", "detected_language_prob": 0.884351986493869, "ents": [{"end": 14, "label": "CARDINAL", "start": 10}, {"end": 27, "label": "DATE", "start": 21}], "nlp_language": "nl", "sents": [{"end": 14, "start": 0}, {"end": 27, "start": 15}], "text": "ik bedoel 6:30 in de middag", "tokens": [{"dep": "nsubj", "end": 2, "head": 1, "id": 0, "lemma": "ik", "morph": "Case=Nom|Person=1|PronType=Prs", "norm": "ik", "pos": "PRON", "start": 0, "tag": "VNW|pers|pron|nomin|vol|1|ev", "text": "ik"}, {"dep": "ROOT", "end": 9, "head": 1, "id": 1, "lemma": "bedoelen", "morph": "Number=Sing|Tense=Pres|VerbForm=Fin", "norm": "bedoel", "pos": "VERB", "start": 3, "tag": "WW|pv|tgw|ev", "text": "bedoel"}, {"dep": "obj", "end": 14, "head": 1, "id": 2, "lemma": "6:30", "morph": "Gender=Neut|Number=Sing", "norm": "6:30", "pos": "PROPN", "start": 10, "tag": "TW|hoofd|vrij", "text": "6:30"}, {"dep": "case", "end": 17, "head": 5, "id": 3, "lemma": "in", "morph": "", "norm": "in", "pos": "ADP", "start": 15, "tag": "VZ|init", "text": "in"}, {"dep": "det", "end": 20, "head": 5, "id": 4, "lemma": "de", "morph": "Definite=Def", "norm": "de", "pos": "DET", "start": 18, "tag": "LID|bep|stan|rest", "text": "de"}, {"dep": "ROOT", "end": 27, "head": 5, "id": 5, "lemma": "middag", "morph": "Gender=Com|Number=Sing", "norm": "middag", "pos": "NOUN", "start": 21, "tag": "N|soort|ev|basis|zijd|stan", "text": "middag"}]}
              """
              |> Jason.decode!()

  @duckling_json """
                 [{"body": "6:30", "dim": "time", "end": 14, "latent": false, "start": 10, "value": {"grain": "minute", "type": "value", "value": "2025-02-26T06:30:00.000-08:00", "values": [{"grain": "minute", "type": "value", "value": "2025-02-26T06:30:00.000-08:00"}, {"grain": "minute", "type": "value", "value": "2025-02-27T06:30:00.000-08:00"}, {"grain": "minute", "type": "value", "value": "2025-02-28T06:30:00.000-08:00"}]}}, {"body": "30 in de middag", "dim": "time", "end": 27, "latent": false, "start": 12, "value": {"from": {"grain": "hour", "value": "2030-01-01T12:00:00.000-08:00"}, "to": {"grain": "hour", "value": "2030-01-01T18:00:00.000-08:00"}, "type": "interval", "values": [{"from": {"grain": "hour", "value": "2030-01-01T12:00:00.000-08:00"}, "to": {"grain": "hour", "value": "2030-01-01T18:00:00.000-08:00"}, "type": "interval"}, {"from": {"grain": "hour", "value": "2030-01-02T12:00:00.000-08:00"}, "to": {"grain": "hour", "value": "2030-01-02T18:00:00.000-08:00"}, "type": "interval"}, {"from": {"grain": "hour", "value": "2030-01-03T12:00:00.000-08:00"}, "to": {"grain": "hour", "value": "2030-01-03T18:00:00.000-08:00"}, "type": "interval"}]}}]
                 """
                 |> Jason.decode!()

  test "sent spacy BOT-2154, consider all duckling entities" do
    s =
      Sentence.from_spacy(@spacy_json)
      |> Sentence.add_duckling_entities(@duckling_json)

    [t | _] = s.tokenizations

    assert length(Enum.filter(t, &match?(%{value: %{kind: "time"}}, &1))) == 2
  end
end
