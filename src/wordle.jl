using Base.Threads, DrWatson

@enum Match begin
    notInWord = 0
    inWord
    inPlace
end

function clue(value::Int, len::Int)
    clue = Array{Match}(undef, len)
    for i in 1:len
        clue[len - i + 1] = Match(value % 3)
        value ÷= 3
    end
    clue
end

function encode(clue::Vector{Match})
    value = 0
    for c in clue
        value = 3value + Int(c)
    end
    value
end

function codetype(word::AbstractString)
    N = length(word)
    for type in [UInt8, UInt16, UInt32, UInt64]
        if BigInt(3)^N <= BigInt(typemax(type))
            return type
        end
    end
    BigInt
end

function entropy(histogram::AbstractVector{Int})
    N = sum(histogram)
    if N != 0
        h = 0.0
        for n in histogram
            if n !== 0
                h -= n * log2(n)
            end
        end
        (h / N) + log2(N)
    else
        -Inf
    end
end

function entropy(histogram::AbstractMatrix{Int})
    [entropy(@view histogram[:,i]) for i in 1:size(histogram, 2)]
end

function result(guess::String, target::String)
    value = 0
    for i in 1:length(guess)
        c = if guess[i] == target[i]
            inPlace
        elseif contains(target, guess[i])
            inWord
        else
            notInWord
        end
        value = 3value + Int(c)
    end
    value
end

struct Guess{U <: Union{Unsigned,BigInt}}
    word::String
    result::Vector{Match}
    code::U
    function Guess(word::String, result::Vector{Match})
        new{codetype(word)}(word, result, encode(result))
    end

    function Guess(word::String, code::Integer)
        new{codetype(word)}(word, clue(code, length(word)), code)
    end
end

function readdictionary(n::Int)
    condition = word -> length(word) == n && lastindex(word) == n && !contains(word, "'")

    dictionary = if isfile(datadir("words-$n"))
        datadir("words-$n")
    else
        datadir("words")
    end

    @info "Reading dictionary $dictionary"
    words = sort!(unique(map(lowercase, filter(condition, readlines(dictionary)))))
    @info "Read $(length(words)) words"
    words
end

struct Wordle{U <: Union{Unsigned,BigInt}}
    words::Vector{String}
    n::Int
    b::U
    A::Matrix{U}
end

function Wordle(words::Vector{String})
    isempty(words) && error("must provide some words")

    type = codetype(words[1])

    L = length(words[1])
    b = type(3)^L
    N = length(words)
    A = zeros(type, N, N)
    @threads for j in 1:N
        for i in 1:N
            A[i,j] = result(words[j], words[i])
        end
    end
    Wordle{type}(words, L, b, A)
end

Wordle(n::Int) = Wordle(readdictionary(n))

histogram(w::Wordle, word::String) = histogram(w, findfirst(w.words .== word))

function histogram(w::Wordle, i::Int)
    h = zeros(Int, w.b)
    @threads for c in @view w.A[:,i]
        h[c + 1] += 1
    end
    h
end

function histogram(w::Wordle)
    h = zeros(Int, w.b, size(w.A, 2))
    @threads for j in 1:size(w.A, 2)
        for c in @view w.A[:,j]
            h[c + 1, j] += 1
        end
    end
    h
end

function histogram(w::Wordle{U}, possible::AbstractVector{Int}) where U
    h = zeros(Int, w.b, size(w.A, 2))
    @threads for j in 1:size(w.A, 2)
        for x in possible
            h[w.A[x, j] + 1, j] += 1
        end
    end
    h
end

histogram(w::Wordle{U}, guesses::Guess{U}...) where U = histogram(w, possible(w, guesses...))

function possible(w::Wordle{U}, guesses::Guess{U}...) where U
    possible = collect(1:size(w.A, 1))
    for guess in guesses
        intersect!(possible, w[guess])
    end
    possible
end

Base.getindex(w::Wordle, idx::Union{Colon,Integer}...) = getindex(w.A, idx...)
Base.getindex(w::Wordle, word::String) = w[:, findfirst(w.words .== word)]
Base.getindex(w::Wordle{U}, guess::Guess{U}) where U = findall(w[guess.word] .== guess.code)

function bestguess(w::Wordle{U}, guesses::Guess{U}...) where U
    p = possible(w, guesses...)
    if isempty(p)
        return nothing
    end

    entropies = entropy(histogram(w, p))
    h, _ = findmax(entropies)
    best = findall(isapprox.(entropies, h))

    if !iszero(h) && !isinf(h)
        i = rand(best)
        (; entropy=h, word=w.words[i])
    elseif length(p) == 1
        (; entropy=0.0, word=w.words[p[1]])
    else
        @error "Multiple possible, indistinguishable solutions" possible=p
        nothing
    end
end
