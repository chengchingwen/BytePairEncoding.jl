# BytePairEncoding.jl

Pure Julia implementation of the Byte Pair Encoding(BPE) method. 
The design is inspired by the original python package [subword-nmt](https://github.com/rsennrich/subword-nmt) and the byte-level bpe use in [openai-gpt2](https://github.com/openai/gpt-2). `BytePairEncoding.jl` support different tokenize
method(with the help of WordTokenizers.jl). You can simply use set the tokenizer and then Learn the BPE map with it.
