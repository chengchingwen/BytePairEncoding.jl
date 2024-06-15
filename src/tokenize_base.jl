# https://github.com/openai/tiktoken/blob/c0ba74c238d18b4824c25f3c27fc8698055b9a76/tiktoken_ext/openai_public.py#L23
"the regex pattern used by openai gpt2"
function gpt2_regex()
    # pattern = r"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"
    pattern = r"""'(?:[sdmt]|ll|ve|re)| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"""
    return pattern
end

# https://github.com/openai/tiktoken/blob/c0ba74c238d18b4824c25f3c27fc8698055b9a76/tiktoken_ext/openai_public.py#L85
"the regex pattern used by openai cl100k_base"
function cl100k_base_regex()
    # pattern = r"(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}{1,3}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+"
    pattern = r"""'(?i:[sdmt]|ll|ve|re)|[^\r\n\p{L}\p{N}]?+\p{L}+|\p{N}{1,3}| ?[^\s\p{L}\p{N}]++[\r\n]*|\s*[\r\n]|\s+(?!\S)|\s+"""
    return pattern
end

# https://github.com/openai/tiktoken/blob/c0ba74c238d18b4824c25f3c27fc8698055b9a76/tiktoken_ext/openai_public.py#L101-L111
"the regex pattern used by openai o200k_base"
function o200k_base_regex()
    pattern = r"[^\r\n\p{L}\p{N}]?[\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{M}]*[\p{Ll}\p{Lm}\p{Lo}\p{M}]+(?i:'s|'t|'re|'ve|'m|'ll|'d)?|[^\r\n\p{L}\p{N}]?[\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{M}]+[\p{Ll}\p{Lm}\p{Lo}\p{M}]*(?i:'s|'t|'re|'ve|'m|'ll|'d)?|\p{N}{1,3}| ?[^\s\p{L}\p{N}]+[\r\n/]*|\s*[\r\n]+|\s+(?!\S)|\s+"
    return pattern
end

regex_tokenize(regex, text) = collect(FindAllIterator(regex, text))
gpt2_tokenizer(text) = regex_tokenize(gpt2_regex(), text)
cl100k_base_tokenizer(text) = regex_tokenize(cl100k_base_regex(), text)
o200k_base_tokenizer(text) = regex_tokenize(o200k_base_regex(), text)
