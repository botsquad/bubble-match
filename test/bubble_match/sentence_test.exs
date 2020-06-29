defmodule BubbleMatch.SentenceTest do
  use ExUnit.Case

  alias BubbleMatch.{Entity, Sentence}

  test "tokenize" do
    sentence = Sentence.naive_tokenize("My birthday, is the day after tomorrow, 10 miles away")

    graph = Sentence.make_dot(sentence)
    assert String.contains?(graph, "start -> v0")
    assert String.contains?(graph, "v0 -> v1")
    assert String.contains?(graph, "v1 -> v2")
    # punct is skipped
    assert String.contains?(graph, "v1 -> v3")
  end

  @spacy_json """
              {"ents":[{"end":27,"label":"PERSON","start":21}],"sents":[{"end":9,"start":0},{"end":27,"start":10}],"text":"Hi there. My name is George","tokens":[{"dep":"ROOT","end":2,"head":0,"id":0,"lemma":"hi","norm":"hi","pos":"INTJ","start":0,"string":"Hi ","tag":"UH"},{"dep":"advmod","end":8,"head":0,"id":1,"lemma":"there","norm":"there","pos":"ADV","start":3,"string":"there","tag":"RB"},{"dep":"punct","end":9,"head":0,"id":2,"lemma":".","norm":".","pos":"PUNCT","start":8,"string":". ","tag":"."},{"dep":"poss","end":12,"head":4,"id":3,"lemma":"-PRON-","norm":"my","pos":"DET","start":10,"string":"My ","tag":"PRP$"},{"dep":"nsubj","end":17,"head":5,"id":4,"lemma":"name","norm":"name","pos":"NOUN","start":13,"string":"name ","tag":"NN"},{"dep":"ROOT","end":20,"head":5,"id":5,"lemma":"be","norm":"is","pos":"AUX","start":18,"string":"is ","tag":"VBZ"},{"dep":"attr","end":27,"head":5,"id":6,"lemma":"George","norm":"george","pos":"PROPN","start":21,"string":"George","tag":"NNP"}]}
              """
              |> Jason.decode!()

  test "from_spacy" do
    sentence = Sentence.from_spacy(@spacy_json)

    view_graph(sentence)
    #    System.cmd("dot", ["-Tpng", "/tmp/x.dot"])
    # assert [_, [_, _, _]] = hithere.tokenizations

    # assert [with_ents, raw_tokens] = mynameis.tokenizations

    # assert ~w(my name is george) == Enum.map(raw_tokens, & &1.value["norm"])
    # assert ~w(spacy spacy spacy entity)a == Enum.map(with_ents, & &1.type)

    # assert [_, _, _, %{value: %Entity{value: "George"}}] = with_ents
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

    view_graph(sentence)

    assert [with_ents, with_ents_punct | _] = sentence.tokenizations

    assert [
             %{value: "my"},
             %{value: "birthday"},
             %{value: "is"},
             %{
               type: :entity,
               value: %Entity{kind: "time", value: "2020-04" <> _, extra: %{"grain" => "day"}}
             },
             %{
               type: :entity,
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
    [hithere, _] = Sentence.sentences_from_spacy(@spacy_json)
    assert {:ok, encoded} = Jason.encode(hithere)
    assert "{\"__struct__\":" <> _ = encoded
  end

  test "access; to_string" do
    [hithere, _] = Sentence.sentences_from_spacy(@spacy_json)
    assert "Hi there." == hithere["text"]
    assert "Hi there." == hithere[:text]
    assert "Hi there." == to_string(hithere)
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
    [a, b] = Sentence.sentences_from_spacy(@time_spacy)

    assert [_] = a.tokenizations
    a = a |> Sentence.add_duckling_entities(@time_duckling)
    assert [with_ents, _raw_tokens] = a.tokenizations
    assert List.first(with_ents).value.kind == "time"

    assert [_] = b.tokenizations
    b = b |> Sentence.add_duckling_entities(@time_duckling)
    assert [with_ents, _raw_tokens] = b.tokenizations
    assert List.first(with_ents).value.kind == "time"
  end

  defp view_graph(sentence) do
    graph = Sentence.make_dot(sentence)

    File.write!("/tmp/x.dot", graph)
    :os.cmd('dot /tmp/x.dot -Tpng > /tmp/x.png; eog /tmp/x.png')
  end
end
