using DrWatson

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
    value + 1
end

function entropy(histogram::Vector{Int})
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
        0.0
        -Inf
    end
end

function result(guess::String, target::String)
    result = map(1:length(guess)) do i
        if guess[i] == target[i]
            inPlace
        elseif contains(target, guess[i])
            inWord
        else
            notInWord
        end
    end
    encode(result)
end

struct Guess
    word::String
    result::Vector{Match}
    code::Int
    function Guess(word::String, result::Vector{Match})
        new(word, result, encode(result))
    end

    function Guess(word::String, code::Int)
        new(word, clue(code, length(word)), code)
    end
end

function condition(len::Int)
    word -> length(word) == len && lastindex(word) == len && !contains(word, "'")
end

function readdictionary(len::Int)
    words = readlines(datadir("words"))
    unique(map(lowercase, filter(condition(len), words)))
end

const Partition = Dict{Int, Set{String}}

struct Web
    r::Dict{String, Partition}
end

Web() = Web(Dict{String, Partition}())

function Web(words::Vector{String})
    web = Web()
    for word in words
        partition = Dict{Int, Set{String}}()
        for other in words
            r = result(word, other)
            if haskey(partition, r)
                push!(partition[r], other)
            else
                partition[r] = Set([other])
            end
        end
        @assert sum(length.(values(partition))) == length(words)
        web.r[word] = partition
    end
    @assert length(web.r) == length(words)
    web
end

Web(n::Int) = Web(readdictionary(n))

words(web::Web) = collect(keys(web.r))

function histogram(web::Web, word::String)
    histogram = map(length, values(web.r[word]))
    @assert sum(histogram) == length(web.r)
    histogram
end

function histogram(web::Web, word::String, possible::Set{String})
    map(x -> length(intersect(x, possible)), values(web.r[word]))
end

function condition(web::Web, guesses::Guess...)
    intersect(map(guesses) do guess
        if haskey(web.r, guess.word) && haskey(web.r[guess.word], guess.code)
            web.r[guess.word][guess.code]
        else
            Set{String}()
        end
    end...)
end

entropy(web::Web, word::String) = entropy(histogram(web, word))

function entropy(web::Web, word::String, guesses::Guess...)
    entropy(web, word, condition(web, guesses...))
end

function entropy(web::Web, word::String, possible::Set{String})
    entropy(histogram(web, word, possible))
end

entropy(web::Web, guesses::Guess...) = map(words(web)) do word
    if isempty(guesses)
        return (; entropy=entropy(web, word), word)
    end

    possible = condition(web, guesses...)
    h = entropy(web, word, possible)
    if !iszero(h) || (iszero(h) && word in possible)
        (; entropy=h, word)
    else
        (; entropy=-Inf, word)
    end
end

function scores(web::Web, guesses::Guess...)
    results = entropy(web, guesses...)
    sort!(results, by=x -> x.entropy, rev=true)
end

function bestguess(web::Web, guesses::Guess...)
    ss = scores(web, guesses...)
    i = findlast(s -> isapprox(s.entropy, ss[1].entropy), ss)
    @info "There are $i best guesses"
    ss[rand(1:i)]
end
