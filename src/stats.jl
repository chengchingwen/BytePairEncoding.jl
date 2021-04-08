toStrTuple(bpe::GenericBPE, x::AbstractString) = Tuple(bpe_postprocess(bpe, merges(bpe, x)))

struct Statistic{B<:GenericBPE}
  bpe::B
  vocab::Dict{Tuple, Int}
  vkeys::Vector{Tuple}
  pair_freq::Dict{Pair{String, String}, Int}
  pair_index::Dict{Pair{String, String}, Vector{Int}}
end

Statistic(bper::BPELearner) = Statistic(bper.bpe, bper.vocabs)
function Statistic(bpe::GenericBPE, v::Dict{String, Int})
  vocab = Dict{Tuple, Int}((toStrTuple(bpe, k), v) for (k, v) ∈ pairs(v))
  vkeys = collect(keys(vocab))
  pair_freq = Dict{Pair{String, String}, Int}()
  pair_index = Dict{Pair{String, String}, Vector{Int}}()

  for (i, tp) ∈ enumerate(vkeys)
    for p ∈ bi_pairs(tp)
      pair_freq[p] = get(pair_freq, p, 0) + vocab[tp]
      indices = get!(pair_index, p, Int[])
      push!(indices, i)
    end
  end

  Statistic(bpe, vocab, vkeys, pair_freq, pair_index)
end

"find adjacent element. return a list of Pair"
function bi_pairs(stp)::Vector{Pair{String, String}}
    init, rstp = Iterators.peel(stp)
    map((x)->x[1]=>x[2], zip(stp, rstp))
end

"if only length one, return []"
bi_pairs(stp::Tuple{String}) = Vector{Pair{String, String}}()


"most frequently pair"
most_freq(stats::Statistic) = argmax(stats.pair_freq)

"get pair freq"
get_freq(stats::Statistic, p::Pair) = get(stats.pair_freq, p, 0)

"get word freq"
get_freq(stats::Statistic, str::String) = get_freq(stats, toStrTuple(stats.bpe, str))
get_freq(stats::Statistic, tp) = get(stats.vocab, tp, 0)

"merge the gived pair and update Statistic"
function merge_pair!(stats::Statistic, pair::Pair{String, String})
    bpi = collect(stats.pair_index[pair])
    sort!(bpi); unique!(bpi)
    for index ∈ bpi
        wtp = stats.vkeys[index]
        freq = stats.vocab[wtp]
        delete!(stats.vocab, wtp)

        bps = bi_pairs(wtp)
        nwtp, indices = merged_pairs(bps, pair)
        adjacents = adjacent_pairs(bps, indices)
        mps = setdiff!(bi_pairs(nwtp), bps)

        stats.vkeys[index] = nwtp
        stats.vocab[nwtp] = freq

        update!(stats, index, nwtp, mps)
        update!(stats, index, adjacents)
    end

    delete!(stats.pair_freq, pair)
    delete!(stats.pair_index, pair)
    stats
end

"update Statistic of the new merged pair"
function update!(stats::Statistic, index::Int, nwtp::Tuple, mps::Vector)
    for mp ∈ mps
        stats.pair_freq[mp] = get_freq(stats, mp) + stats.vocab[nwtp]
        indices = get!(stats.pair_index, mp, Int[])
        push!(indices, index)
    end
end

"update Statistic of the removed adjacent pairs"
function update!(stats::Statistic, index::Int, adjacents::Vector)
    for ap ∈ adjacents
        stats.pair_freq[ap] -= stats.vocab[stats.vkeys[index]]
        dindex = findfirst(isequal(index), stats.pair_index[ap])
        dindex !== nothing && deleteat!(stats.pair_index[ap], dindex)
    end
    stats
end

"update a tuple"
function update!(stats::Statistic, index::Int, nwtp::Tuple)
    nbps = bi_pairs(nwtp)
    for np ∈ nbps
        stats.pair_freq[np] = get_freq(stats, np) + stats.vocab[nwtp]
        indices = get!(stats.pair_index, np, Int[])
        push!(indices, index)
    end
    stats
end


"update a word"
function update!(stats::Statistic, str::String; freq::Int = 1)
    stp = toStrTuple(stats.bpe, str)
    if haskey(stats.vocab, stp)
        stats.vocab[stp] += freq
        for sbp ∈ bi_pairs(stp)
            stats.pair_freq[sbp] += freq
        end
    else
        stats.vocab[stp] = get_freq(stats.vocab, stp) + freq
        push!(stats.vkeys, stp)
        update!(stats, length(stats.vkeys), stp)
    end
    stats
end

"update a frequency vocab"
function update!(stats::Statistic, vocab::Dict{String, Int})
    for (word, freq) ∈ vocab
        update!(stats, word; freq=freq)
    end
    stats
end

"get the adjacent pair of merged pair"
adjacent_pairs(wtp::Tuple, pair::Pair{String, String}) = adjacent_pairs(bi_pairs(wtp), pair)
function adjacent_pairs(_bps::Array{Pair{String, String}}, pair::Pair{String, String})
    bps = collect(_bps)
    indice = Vector{Int}()

    merged = intern(join(pair))
    for (i, x) ∈ enumerate(bps)
        if 1<i && bps[i-1] == pair
            bps[i] = merged=>x.second
        elseif x == pair
            push!(indice, i)
        end
    end
    adjacent_pairs(_bps, indice)
end

function adjacent_pairs(bps::Array{Pair{String, String}}, indices::Vector{Int})
    adjs = filter!((i)->1<=i<=length(bps), unique!(foldl((l,r)->(push!(l, r-1);push!(l, r);push!(l, r+1);l), indices, init=Int[])))
    bps[adjs]
end

"merge the pair in the word tuple"
merged_pairs(wtp::Tuple, pair::Pair{String, String}) = merged_pairs(bi_pairs(wtp), pair)
function merged_pairs(bps::Array{Pair{String, String}}, pair::Pair{String, String})
    bps = collect(bps)
    nwss = Vector{String}()
    indice = Vector{Int}()

    merged = intern(join(pair))
    for (i, x) ∈ enumerate(bps)
        if 1<i && bps[i-1] == pair
            bps[i] = merged=>x.second
        elseif x == pair
            push!(nwss, merged)
            push!(indice, i)
            continue
        else
            push!(nwss, x.first)
        end

        if i == length(bps)
            push!(nwss, x.second)
        end
    end
    Tuple(nwss), indice
end
