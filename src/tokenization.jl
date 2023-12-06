using DataStructures: MutableLinkedList
using TextEncodeBase
using TextEncodeBase: AbstractTokenizer,
    AbstractTokenization, BaseTokenization, WordNormalizer, DefaultTokenization, WrappedTokenization, Splittable,
    ParentStages, TokenStages, TokenStage, SentenceStage, WordStage, getvalue, CodeNormalizer

struct GPT2Tokenization <: BaseTokenization end
TextEncodeBase.splitting(::GPT2Tokenization, s::SentenceStage) = gpt2_tokenizer(getvalue(s))

struct Cl100kBaseTokenization <: BaseTokenization end
TextEncodeBase.splitting(::Cl100kBaseTokenization, s::SentenceStage) = cl100k_base_tokenizer(getvalue(s))

struct BPETokenization{T <: AbstractTokenization, B <: AbstractBPE} <: WrappedTokenization{T}
    base::T
    bpe::B
end
BPETokenization(bpe::AbstractBPE) = BPETokenization(DefaultTokenization(), bpe)
BPETokenization(base::AbstractTokenization) = BPETokenization(base, NoBPE())

TextEncodeBase.splittability(::ParentStages, ::BPETokenization, ::WordStage) = Splittable()
TextEncodeBase.splitting(::ParentStages, t::BPETokenization, w::WordStage) = t.bpe(getvalue(w))


struct BPETokenizer{T<:AbstractTokenization} <: AbstractTokenizer
    tokenization::T
end
BPETokenizer() = BPETokenizer(DefaultTokenization())

(tkr::BPETokenizer)(x::AbstractString) = tkr(TextEncodeBase.Sentence(x))

TextEncodeBase.tokenization(tkr::BPETokenizer) = tkr.tokenization

function TextEncodeBase.tokenize(tkr::BPETokenizer, s::ParentStages, t::AbstractTokenization, x::TokenStages)
    if isnothing(s)
        return TextEncodeBase.tokenize_procedure!(
            TextEncodeBase.splittability, MutableLinkedList{String}(),
            tkr, nothing, t, x) do list, tokens
                for token in Iterators.map(getvalue, tokens)
                    push!(list, token)
                end
            end |> collect
    else
        return TextEncodeBase.tokenize_procedure(tkr, s, t, x)
    end
end
@inline TextEncodeBase.tokenize(tkr::BPETokenizer, s::ParentStages, t::AbstractTokenization, x::TokenStage) =
    isempty(getvalue(x)) ? TokenStage[] : TokenStage[TextEncodeBase.wrap(tkr, s, t, x)]
