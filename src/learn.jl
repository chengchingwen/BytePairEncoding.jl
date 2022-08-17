using TextEncodeBase: FlatTokenizer, Document, getvalue, TokenizerStyle
using StructWalk: scan

include("stats.jl")

"""
    BPELearner(tokenization::AbstractTokenization; min_freq = 10, endsym = "</w>", sepsym = nothing)

Construct a learner with a `tokenization` which has `BPETokenization` and `NoBPE` inside.

    (bper::BPELearner)(word_counts, n_merge)

Calling the learner on a `word_counts` dictionary (created by [`count_words`](@ref)) generate a new `tokenization`
  where `NoBPE` is replaced with the learned `BPE`.
"""
struct BPELearner{T<:AbstractTokenizer}
    tokenizer::T
    min_freq::Int
    endsym::Union{String, Nothing}
    sepsym::Union{String, Nothing}
end

BPELearner(tokenization::AbstractTokenization; kws...) = BPELearner(FlatTokenizer(tokenization); kws...)
function BPELearner(tokenizer::AbstractTokenizer; min_freq = 10, endsym = "</w>", sepsym = nothing)
    check = Ref{Bool}(false)
    scan(x -> x isa BPETokenization && x.bpe isa NoBPE && (check[] = true), TokenizerStyle(), tokenizer)
    check[] || error("tokenizer does not have BPETokenization with NoBPE.")
    return BPELearner(tokenizer, min_freq, endsym, sepsym)
end

"""
    count_words(bper::BPELearner, files::AbstractVector)

Given a list of files (where each line of the file would be considered as a (multi-sentences) document).
  Tokenize those file a count the occurence of each word token.
"""
count_words(bper::BPELearner, files::AbstractVector) = foldl(mergewith!(+), map(Base.Fix1(count_words, bper), files); init = Dict{String, Int}())
count_words(bper::BPELearner, file::AbstractString) = open(Base.Fix1(count_words, bper), file)
function count_words(bper::BPELearner, io::IO)
    word_counts = Dict{String, Int}()
    for line in eachline(io)
        count_words!(bper, word_counts, line)
    end
    return word_counts
end

count_words!(bper::BPELearner, word_counts, line::AbstractString) = count_words!(bper, word_counts, Document(line))
function count_words!(bper::BPELearner, word_counts, input::TextEncodeBase.TokenStages)
    for token in Iterators.map(String ∘ getvalue, bper.tokenizer(input))
        word_counts[token] = get(word_counts, token, 0) + 1
    end
    return word_counts
end

(bper::BPELearner)(word_counts, n_merge; cached = true) = bper(argmax, word_counts, n_merge; cached)
function (bper::BPELearner)(f, word_counts, n_merge; cached = true)
    rank = learn(f, word_counts, n_merge, bper.endsym, bper.min_freq)
    bpe = BPE(rank; sepsym = bper.sepsym, endsym = bper.endsym)
    cached && (bpe = CachedBPE(bpe))
    return replace(TextEncodeBase.tokenization(bper.tokenizer)) do x
        if x isa BPETokenization && x.bpe isa NoBPE
            return BPETokenization(x.base, bpe)
        else
            return x
        end
    end
end
