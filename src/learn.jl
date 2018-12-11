using WordTokenizers
using InternedStrings

"simply the built-in split function for the origin tokenize method in subword-nmt"
whitespace_tokenize(str::AbstractString) = split(str)

"get vocab with frequency counts"
function get_vocab(vfile::AbstractString; normalizer)
    vocab = Dict{String, Int}()
    open(vfile) do io
        for line ∈ eachline(io)
            line = normalize(normalizer, line)
            for word ∈ intern.(tokenize(line))
                vocab[word] = get(vocab, word, 0) + 1
            end
        end
    end
    vocab
end

struct BPELearner
    num_sym::Int
    min_freq::Int
    endsym::String
    vfiles::Vector{String}

    stats::Statistic
    result::Vector{Pair{String, String}}

    normalizer::AbstractNormalizer

    function BPELearner(vfiles::Vector{String}, num_sym::Int;
                        min_freq::Int = 2, endsym::String = "</w>",
                        normalizer=UnNormalizer())
        vocab = mapreduce((f)->get_vocab(f; normalizer=normalizer), merge!, vfiles)
        stats = Statistic(vocab)
        endsym != "</w>" && set_endsym(endsym)
        new(num_sym, min_freq, endsym, vfiles,
            stats,
            Vector{Pair{String, String}}(undef, num_sym),
            normalizer)
    end
end

"add a new file to learner"
function add!(bper::BPELearner, vfile::String)
    push!(bper.vfiles, vfile)
    nv = get_vocab(vfile; normalizer=bper.normalizer)
    update!(bper.stats, nv)
end

"learn a BPE map"
function learn!(bper::BPELearner)
    if isassigned(bper.result)
        bper.result = Vector(undef, bper.num_sym)
    end

    for i ∈ 1:bper.num_sym
        mfp = most_freq(bper.stats)
        get_freq(bper.stats, mfp) < bper.min_freq && (resize!(bper.result, i-1); break)
        merge_pair!(bper.stats, mfp)
        bper.result[i] = mfp
    end
end

"emit the BPE map to ofile; can add one-line comment to the header(first line)"
function emit(bper::BPELearner, ofile::AbstractString; comment::String = "")
    @assert '\n' ∉ comment && '\r' ∉ comment
    open(ofile, "w+") do fo
        write(fo, ":$comment#endsym:$(bper.endsym)\n")
        for (f, s) ∈ bper.result
            write(fo, f, " ", s, "\n")
        end
    end
    ofile
end

function Base.show(io::IO, b::BPELearner)
    println(io, "BPELearner(",
            "num_sym=$(b.num_sym), ",
            "min_freq=$(b.min_freq), ",
            "endsym=\"$(b.endsym)\", ",
            "normailzer=$(typeof(b.normalizer)))")
    io
end
