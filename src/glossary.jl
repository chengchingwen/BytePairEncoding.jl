"regex escape from https://github.com/JuliaLang/julia/pull/29643"
function _regex_escape(s::AbstractString)
    res = replace(s, r"([()[\]{}?*+\-|^\$\\.&~#\s=!<>|:])" => s"\\\1")
    replace(res, "\0" => "\\0")
end

"isolate given glossary in a word"
isolate_gloss(word::String, gloss::String)::Vector{String} = isolate_gloss(word, _regex_escape(gloss))
function isolate_gloss(word::String, gloss::Regex)
    if occursin(gloss, word) && !occursin(Regex("^"*gloss.pattern*"\$"), word)
        splits = split(word, gloss)
        matched = collect(eachmatch(gloss, word))
        res = String[]
        foreach(zip(splits, matched)) do (s, m)
            s != "" && push!(res, intern(s))
            m.match != "" && push!(res, intern(m.match))
        end
        splits[end] != "" && push!(res, intern(splits[end]))
    else
        res = String[intern(word)]
    end
    res
end

function isolate_gloss(word::String, glosses::Vector{Union{Regex, String}})
    word = String[word]
    for gloss ∈ glosses
        len = length(word)
        for i ∈ 1:len
            wp = popfirst!(word)
            foreach(isolate_gloss(wp, gloss)) do nwp
                push!(word, nwp)
            end
        end
    end
    word
end

