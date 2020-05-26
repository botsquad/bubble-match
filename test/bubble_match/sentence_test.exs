defmodule BubbleMatch.SentenceTest do
  use ExUnit.Case

  alias BubbleMatch.Sentence

  @spacy_json """
              {"ents":[{"end":27,"label":"PERSON","start":21}],"sents":[{"end":9,"start":0},{"end":27,"start":10}],"text":"Hi there. My name is George","tokens":[{"dep":"ROOT","end":2,"head":0,"id":0,"lemma":"hi","norm":"hi","pos":"INTJ","start":0,"string":"Hi ","tag":"UH"},{"dep":"advmod","end":8,"head":0,"id":1,"lemma":"there","norm":"there","pos":"ADV","start":3,"string":"there","tag":"RB"},{"dep":"punct","end":9,"head":0,"id":2,"lemma":".","norm":".","pos":"PUNCT","start":8,"string":". ","tag":"."},{"dep":"poss","end":12,"head":4,"id":3,"lemma":"-PRON-","norm":"my","pos":"DET","start":10,"string":"My ","tag":"PRP$"},{"dep":"nsubj","end":17,"head":5,"id":4,"lemma":"name","norm":"name","pos":"NOUN","start":13,"string":"name ","tag":"NN"},{"dep":"ROOT","end":20,"head":5,"id":5,"lemma":"be","norm":"is","pos":"AUX","start":18,"string":"is ","tag":"VBZ"},{"dep":"attr","end":27,"head":5,"id":6,"lemma":"George","norm":"george","pos":"PROPN","start":21,"string":"George","tag":"NNP"}]}
              """
              |> Jason.decode!()

  test "from_spacy" do
    [hithere, mynameis] = Sentence.sentences_from_spacy(@spacy_json)

    assert [_, [_, _, _]] = hithere.tokenizations

    assert [with_ents, _no_punct, raw_tokens] = mynameis.tokenizations

    assert ~w(my name is george) == Enum.map(raw_tokens, & &1.value.norm)
    assert ~w(spacy spacy spacy entity)a == Enum.map(with_ents, & &1.type)
  end

  test "match from spacy" do
    all = [hithere, mynameis] = Sentence.sentences_from_spacy(@spacy_json)

    assert {:match, _} = BubbleMatch.Matcher.match("%NOUN", mynameis)

    assert {:match, _} = BubbleMatch.Matcher.match("my name is", mynameis)
    assert :nomatch = BubbleMatch.Matcher.match("my name is", hithere)

    assert {:match, _} = BubbleMatch.Matcher.match("[Start] my name is", all)
    assert {:match, _} = BubbleMatch.Matcher.match("hi there \".\" [End]", all)
    assert {:match, m} = BubbleMatch.Matcher.match("[person]", all)

    assert [%{value: %{kind: "person", value: "George"}}] = m["person"]
  end

  @hello_world_json """
                    {"text": "Hello, w\u00f3rld", "ents": [], "sents": [{"start": 0, "end": 12}], "tokens": [{"id": 0, "start": 0, "end": 5, "pos": "INTJ", "tag": "UH", "dep": "ROOT", "head": 0, "string": "Hello", "lemma": "hello", "norm": "hello"}, {"id": 1, "start": 5, "end": 6, "pos": "PUNCT", "tag": ",", "dep": "punct", "head": 2, "string": ", ", "lemma": ",", "norm": ","}, {"id": 2, "start": 7, "end": 12, "pos": "NOUN", "tag": "NN", "dep": "npadvmod", "head": 0, "string": "w\u00f3rld", "lemma": "w\u00f3rld", "norm": "w\u00f3rld"}]}
                    """
                    |> Jason.decode!()

  test "spacy ignore punctuation, strip accents" do
    [sent] = Sentence.sentences_from_spacy(@hello_world_json)

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

    assert [with_ents, _without_punct, _raw_tokens] = sentence.tokenizations

    assert [
             %{value: "my"},
             %{value: "birthday"},
             %{value: "is"},
             %{type: :entity, value: %{kind: "time", value: %{"grain" => "day"}}},
             _comma,
             %{
               type: :entity,
               value: %{kind: "distance", value: %{"unit" => "mile", "value" => 10}}
             },
             _awai
           ] = with_ents
  end

  test "encoding" do
    [hithere, _] = Sentence.sentences_from_spacy(@spacy_json)
    assert {:ok, _} = Jason.encode(hithere)
  end

  test "access; to_string" do
    [hithere, _] = Sentence.sentences_from_spacy(@spacy_json)
    assert "Hi there." == hithere["text"]
    assert "Hi there." == hithere[:text]
    assert "Hi there." == to_string(hithere)
  end
end
