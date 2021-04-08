import Base.Unicode: utf8proc_map, normalize, UTF8PROC_STABLE, UTF8PROC_COMPAT, UTF8PROC_DECOMPOSE, UTF8PROC_COMPOSE, UTF8PROC_IGNORE, UTF8PROC_REJECTNA, UTF8PROC_NLF2LS, UTF8PROC_NLF2PS, UTF8PROC_NLF2LF, UTF8PROC_STRIPCC, UTF8PROC_CASEFOLD, UTF8PROC_LUMP, UTF8PROC_STRIPMARK


function _compute_options(
    stable::Bool=false,
    compat::Bool=false,
    compose::Bool=false,
    decompose::Bool=false,
    stripignore::Bool=false,
    rejectna::Bool=false,
    newline2ls::Bool=false,
    newline2ps::Bool=false,
    newline2lf::Bool=false,
    stripcc::Bool=false,
    casefold::Bool=false,
    lump::Bool=false,
    stripmark::Bool=false,
)
    flags = 0
    stable && (flags = flags | UTF8PROC_STABLE)
    compat && (flags = flags | UTF8PROC_COMPAT)
    # TODO: error if compose & decompose?
    if decompose
        flags = flags | UTF8PROC_DECOMPOSE
    elseif compose
        flags = flags | UTF8PROC_COMPOSE
    elseif compat || stripmark
        throw(ArgumentError("compat=true or stripmark=true require compose=true or decompose=true"))
    end
    stripignore && (flags = flags | UTF8PROC_IGNORE)
    rejectna && (flags = flags | UTF8PROC_REJECTNA)
    newline2ls + newline2ps + newline2lf > 1 && throw(ArgumentError("only one newline conversion may be specified"))
    newline2ls && (flags = flags | UTF8PROC_NLF2LS)
    newline2ps && (flags = flags | UTF8PROC_NLF2PS)
    newline2lf && (flags = flags | UTF8PROC_NLF2LF)
    stripcc && (flags = flags | UTF8PROC_STRIPCC)
    casefold && (flags = flags | UTF8PROC_CASEFOLD)
    lump && (flags = flags | UTF8PROC_LUMP)
    stripmark && (flags = flags | UTF8PROC_STRIPMARK)
    flags
end

_compute_options(nf::Symbol) =
    nf == :NFC ? (UTF8PROC_STABLE | UTF8PROC_COMPOSE) :
    nf == :NFD ? (UTF8PROC_STABLE | UTF8PROC_DECOMPOSE) :
    nf == :NFKC ? (UTF8PROC_STABLE | UTF8PROC_COMPOSE | UTF8PROC_COMPAT) :
    nf == :NFKD ? (UTF8PROC_STABLE | UTF8PROC_DECOMPOSE | UTF8PROC_COMPAT) :
    nf == :NFKC_CF ? (UTF8PROC_STABLE | UTF8PROC_COMPOSE | UTF8PROC_COMPAT | UTF8PROC_CASEFOLD) :
    throw(ArgumentError(":$nf is not one of :NFC, :NFD, :NFKC, :NFKD, :NFKC_CF"))


#normalize(s::AbstractString, nf::Symbol) = utf8proc_map(s, _compute_options(nf))
normalize(s::AbstractString, option::Int) = utf8proc_map(s, option)

abstract type AbstractNormalizer end

struct UnNormalizer <: AbstractNormalizer end

normalize(::UnNormalizer, s::AbstractString) = s


struct UtfNormalizer <: AbstractNormalizer
    option::Int
end

"""
  UtfNormalizer(nf=[:NFC, :NFD, NFKC, :NFKD, :NFKC_CF]::Symbol)

unicode normalization.

possible value of `nf`:
1. NFC (Normalization Form Canonical Composition): Characters are decomposed and then recomposed by canonical equivalence.
2. NFD (Normalization Form Canonical Decomposition): Characters are decomposed by canonical equivalence, and multiple combining characters are arranged in a specific order.
3. NFKC (Normalization Form Compatibility Composition): Characters are decomposed by compatibility, then recomposed by canonical equivalence.
4. NFKD (Normalization Form Compatibility Decomposition): Characters are decomposed by compatibility, and multiple combining characters are arranged in a specific order.
5. NFKC_CF: NFKC + case folding
"""
UtfNormalizer(nf::Symbol) = UtfNormalizer(_compute_options(nf))
function UtfNormalizer(
    stable::Bool=false,
    compat::Bool=false,
    compose::Bool=false,
    decompose::Bool=false,
    stripignore::Bool=false,
    rejectna::Bool=false,
    newline2ls::Bool=false,
    newline2ps::Bool=false,
    newline2lf::Bool=false,
    stripcc::Bool=false,
    casefold::Bool=false,
    lump::Bool=false,
    stripmark::Bool=false,
)
    return UtfNormalizer(
        _compute_options(
            stable=stable,
            compat=compat,
            compose=compose,
            decompose=decompose,
            stripignore=stripignore,
            rejectna=rejectna,
            newline2ls=newline2ls,
            newline2ps=newline2ps,
            newline2lf=newline2lf,
            stripcc=stripcc,
            casefold=casefold,
            lump=lump,
            stripmark=stripmark,
        )
    )
end

normalize(nr::UtfNormalizer, s::AbstractString) = normalize(s, nr.option)

(norm::UnNormalizer)(s::AbstractString) = s
(norm::UtfNormalizer)(s::AbstractString) = normalize(norm, s)
