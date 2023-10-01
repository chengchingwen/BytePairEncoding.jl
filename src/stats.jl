#=
  A minimum implementation of the byte pair encoding learning algorithm.

  Calculate the frequency of occurence of each sub-string pairs appears in vocabulary and
    generate a lookup table of each pair where smaller number means higher merge priority.

  Fields

    pair_freq: a lookup table for getting the occurence frequency of a substring pair.

    pair_index: a lookup table for getting a list of index of where the pair appears in.

    vocab: a lookup table for getting the occurence frequency of a word (in the form of list of substrings)

    vkeys: a list of words (in the form of list of substrings)
=#

struct Statistic
    endsym::Union{String, Nothing}
    vocab::Dict{Vector{String}, Int}
    vkeys::Vector{Vector{String}}
    pair_freq::Dict{Pair{String, String}, Int}
    pair_index::Dict{Pair{String, String}, Vector{Int}}
end

function Statistic(word_counts::Dict{String, Int}, endsym)
    _bpe = BPE(Dict(); endsym = endsym)
    vocab = Dict{Vector, Int}((bpe_units(_bpe, word), freq) for (word, freq) ∈ pairs(word_counts))
    vkeys = collect(keys(vocab))
    pair_freq = Dict{Pair{String, String}, Int}()
    pair_index = Dict{Pair{String, String}, Vector{Int}}()

    for (index, word_units) ∈ enumerate(vkeys)
        for pair ∈ bi_pairs(word_units)
            pair_freq[pair] = get(pair_freq, pair, 0) + vocab[word_units]
            indices = get!(pair_index, pair, Int[])
            push!(indices, index)
        end
    end

    Statistic(endsym, vocab, vkeys, pair_freq, pair_index)
end

# convert string into list of character units for later merging
bpe_units(_bpe, x::AbstractString) = as_string.(first.(merges(_bpe, x)), nothing, _bpe.endsym)

# find adjacent element. return a list of Pair, if only length one, return []
bi_pairs(t) = map(Base.splat(=>), zip(t, Iterators.drop(t, 1)))

# most frequently pair
Base.argmax(stats::Statistic) = argmax(stats.pair_freq)

# get frequency
Base.getindex(stats::Statistic, p::Pair) = get(stats.pair_freq, p, 0)

# merge the gived pair and update Statistic
function merge_pair!(stats::Statistic, pair::Pair{String, String})
    # migth have duplicate index becuase one word can have more than one occurence of a pair
    word_w_pair = unique(stats.pair_index[pair])
    for index ∈ word_w_pair
        word_units = stats.vkeys[index]
        freq = stats.vocab[word_units]
        delete!(stats.vocab, word_units) # pair would be merged, this word units (w/o merged) doesn't exist anymore

        bipairs = bi_pairs(word_units)
        new_word_units, merged_indices = merged_pairs(bipairs, pair)
        adjacents = adjacent_pairs(bipairs, merged_indices)
        merged_bipairs = setdiff!(bi_pairs(new_word_units), bipairs)

        stats.vkeys[index] = new_word_units # update the word units to the new one (w/ merged)
        stats.vocab[new_word_units] = freq  # set the frequency

        update!(stats, index, new_word_units, merged_bipairs)
        update!(stats, index, adjacents)
    end

    delete!(stats.pair_freq, pair)
    delete!(stats.pair_index, pair)
    stats
end

# update Statistic of the new merged pair
function update!(stats::Statistic, index::Int, new_word_units, merged_bipairs)
    for mp ∈ merged_bipairs
        stats.pair_freq[mp] = get(stats.pair_freq, mp, 0) + stats.vocab[new_word_units]
        indices = get!(stats.pair_index, mp, Int[])
        push!(indices, index)
    end
    return
end

# update Statistic of the removed adjacent pairs
function update!(stats::Statistic, index::Int, adjacents)
    for ap ∈ adjacents
        stats.pair_freq[ap] -= stats.vocab[stats.vkeys[index]]
        dindex = findfirst(isequal(index), stats.pair_index[ap])
        dindex !== nothing && deleteat!(stats.pair_index[ap], dindex)
    end
    return
end

# get the adjacent pair of merged pair, they should be update to be adjacent to the new merged pair
adjacent_pairs(bipairs::Array{Pair{String, String}}, indices::Vector{Int}) =
    bipairs[filter!(∈(1:length(bipairs)), unique!(foldl((init,r)-> push!(init, r-1, r, r+1), indices; init = Int[])))]

# merge the pair in the word tuple, return the new word units and indices where merge happened in the origin bipairs.
function merged_pairs(bipairs::Array{Pair{String, String}}, pair::Pair{String, String})
    bipairs = collect(bipairs)
    new_pairs = String[]
    indice = Int[]

    merged = join(pair)
    for (i, x) ∈ enumerate(bipairs)
        if 1<i && bipairs[i-1] == pair
            bipairs[i] = merged=>x.second
        elseif x == pair
            push!(new_pairs, merged)
            push!(indice, i)
            continue
        else
            push!(new_pairs, x.first)
        end

        if i == length(bipairs)
            push!(new_pairs, x.second)
        end
    end
    new_pairs, indice
end

learn(word_counts, n_merge::Int, endsym::Union{Nothing, String} = nothing, min_freq::Int = 10) =
    learn(argmax, word_counts, n_merge, endsym, min_freq)
function learn(f, word_counts, n_merge::Int, endsym::Union{Nothing, String} = nothing, min_freq::Int = 10)
    merging_rank = Dict{NTuple{2, Merge}, Int}()
    pattern = isnothing(endsym) ? nothing : Regex("(.*)\\Q$endsym\\E\$")
    stats = Statistic(word_counts, endsym)
    for i = 1:n_merge
        most_freq_pair = f(stats)
        stats[most_freq_pair] < min_freq && break
        merge_pair!(stats, most_freq_pair)
        merging_rank[parse_merge(Tuple(most_freq_pair), pattern)] = i
    end
    return merging_rank
end
