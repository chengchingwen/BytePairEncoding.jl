# Learning BPE

We also provide the functionality to learn new BPE map accordingly.


```julia
# create a bpe we want to learn
julia> mybpe = GenericBPE{String}(; oldendsym = "@w@", sepsym = "=",
	input_transform = BytePairEncoding.gpt2_tokenizer, codemap = BytePairEncoding.default_codemap(),
	normalizer = BytePairEncoding.UtfNormalizer(:NFKC_CF), glossaries = BytePairEncoding.Glossary([r"[0-9]"]))
GenericBPE{String}(n_merge=0, endsym=@w@, sepsym==, oldendsym=@w@, input_transform=gpt2_tokenizer, glossaries=BytePairEncoding.Glossary(Regex[r"[0-9]"]), codemap=BytePairEncoding.CodeMap{UInt8, UInt16}(StepRange{Char, Int64}['\0':1:' ', '\x7f':1:' ', '\uad':1:'\uad'], StepRange{Char, Int64}['Ā':1:'Ġ', 'ġ':1:'ł', 'Ń':1:'Ń']), normalizer=UtfNormalizer(1038))

# create the learner
julia> bper = BPELearner(mybpe, 5000, 10)
BPELearner(bpe = GenericBPE{String}(n_merge=0, endsym=@w@, sepsym==, oldendsym=@w@, input_transform=gpt2_tokenizer, glossaries=BytePairEncoding.Glossary(Regex[r"[0-9]"]), codemap=BytePairEncoding.CodeMap{UInt8, UInt16}(StepRange{Char, Int64}['\0':1:' ', '\x7f':1:' ', '\uad':1:'\uad'], StepRange{Char, Int64}['Ā':1:'Ġ', 'ġ':1:'ł', 'Ń':1:'Ń']), normalizer=UtfNormalizer(1038)), merge = 5000, min_freq = 10)

# add corpus to the learner
julia> add!(bper, "./test/data/corpus.en")
Dict{String, Int64} with 4244 entries:
  "Ġexceedingly" => 2
  "Ġqueue"       => 3
  "Ġfell"        => 2
  "Ġlocal"       => 3
  "Ġaspiration"  => 1
  "Ġadvancement" => 1
  "Ġentrusts"    => 1
  "Ġhad"         => 31
  "Ġretained"    => 1
  "Ġcowdery"     => 1
  "Ġnicer"       => 1
  "Ġmission"     => 1
  "Ġtime"        => 39
  "Ġexecuted"    => 1
  "rather"       => 1
  "Ġsafely"      => 3
  "Ġmakes"       => 1
  "Ġreach"       => 1
  "these"        => 2
  "Ġenough"      => 2
  "Ġspot"        => 3
  "Ġusers"       => 22
  "Ġpasta"       => 1
  "Ġmode"        => 1
  "Ġlargely"     => 2
  "Ġmain"        => 7
  ⋮              => ⋮


# learn the bpe
julia> learn!(bper)
GenericBPE{String}(n_merge=1168, endsym=@w@, sepsym==, oldendsym=@w@, input_transform=gpt2_tokenizer, glossaries=BytePairEncoding.Glossary(Regex[r"[0-9]"]), codemap=BytePairEncoding.CodeMap{UInt8, UInt16}(StepRange{Char, Int64}['\0':1:' ', '\x7f':1:' ', '\uad':1:'\uad'], StepRange{Char, Int64}['Ā':1:'Ġ', 'ġ':1:'ł', 'Ń':1:'Ń']), normalizer=UtfNormalizer(1038))

# test our learned bpe
julia> mybpe(" Is this a 😺")
8-element Vector{String}:
 "Ġis@w@"
 "Ġthis@w@"
 "Ġa@w@"
 "Ġ="
 "ð="
 "Ł="
 "ĺ="
 "º@w@"

# dump the learned bpe
julia> emit(bper, "./bpe.out")
"./bpe.out"

```
