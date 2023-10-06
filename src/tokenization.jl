using TextEncodeBase
using TextEncodeBase: BaseTokenization, WordNormalizer, DefaultTokenization, WrappedTokenization, Splittable,
    ParentStages, TokenStages, SentenceStage, WordStage, getvalue, CodeNormalizer

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
