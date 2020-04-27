defmodule BubbleExpr.SentenceTest do
  use ExUnit.Case

  alias BubbleExpr.Sentence
  alias BubbleExpr.Token

  @tag skip: true
  test "add_tokenization" do
    sentence = Sentence.naive_tokenize("Hello, world!")
    new_tokens = [%Token{index: 0, raw: "Hello,", start: 0, end: 6, value: "hullo"}]
    sentence = Sentence.add_tokenization(sentence, new_tokens)

    assert [
             [
               %Token{index: 0, raw: "Hello,", start: 0, end: 6, value: "hullo"},
               %Token{index: 1, raw: "world!", start: 7, end: 13, value: "world"}
             ],
             [_, _]
           ] = sentence.tokenizations

    # sentence = Sentence.naive_tokenize("Hello, world!")
    # new_tokens = [%Token{index: 0, raw: "Hello, world!", start: 0, end: 6, value: "yo"}]
    # sentence = Sentence.add_tokenization(sentence, 0, 2, new_tokens)
    # assert [%{value: "yo"}] = sentence.tokens
  end

  @spacy_json """
              {"ents":[{"end":27,"label":"PERSON","start":21}],"sents":[{"end":9,"start":0},{"end":27,"start":10}],"text":"Hi there. My name is George","tokens":[{"dep":"ROOT","end":2,"head":0,"id":0,"lemma":"hi","norm":"hi","pos":"INTJ","start":0,"string":"Hi ","tag":"UH"},{"dep":"advmod","end":8,"head":0,"id":1,"lemma":"there","norm":"there","pos":"ADV","start":3,"string":"there","tag":"RB"},{"dep":"punct","end":9,"head":0,"id":2,"lemma":".","norm":".","pos":"PUNCT","start":8,"string":". ","tag":"."},{"dep":"poss","end":12,"head":4,"id":3,"lemma":"-PRON-","norm":"my","pos":"DET","start":10,"string":"My ","tag":"PRP$"},{"dep":"nsubj","end":17,"head":5,"id":4,"lemma":"name","norm":"name","pos":"NOUN","start":13,"string":"name ","tag":"NN"},{"dep":"ROOT","end":20,"head":5,"id":5,"lemma":"be","norm":"is","pos":"AUX","start":18,"string":"is ","tag":"VBZ"},{"dep":"attr","end":27,"head":5,"id":6,"lemma":"George","norm":"george","pos":"PROPN","start":21,"string":"George","tag":"NNP"}]}
              """
              |> Jason.decode!()

  test "from_spacy" do
    sentence = Sentence.from_spacy(@spacy_json)
    [tokens] = sentence.tokenizations

    assert ~w(hi there . my name is george) == Enum.map(tokens, & &1.value.norm)
  end

  test "match from spacy" do
    sentence = Sentence.from_spacy(@spacy_json)

    assert {:match, _} = BubbleExpr.Matcher.match("my name is", sentence)
  end
end
