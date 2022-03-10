using DrWatson, ProgressMeter, Statistics

include(srcdir("wordle.jl"))

function play(w::Wordle, target::String)
    winning_code = encode([inPlace for _ in target])
    guesses = []
    count = 0
    while true
        count += 1
        g = bestguess(w, guesses...)
        if isnothing(g)
            count = Inf
            break
        end
        code = result(g.word, target)
        if code == winning_code
            break
        end
        push!(guesses, Guess(g.word, code))
    end
    count
end

function main(n)
    wordle = Wordle(n)
    N = length(wordle.words)
    nq = zeros(N)
    meter = Progress(N)
    @time @threads for i in 1:N
        nq[i] = mean(play(wordle, wordle.words[i]) for _ in 1:10)
        next!(meter)
    end
    min, max = extrema(nq)
    μ, σ = mean(nq), std(nq)
    best, worst = wordle.words[findall(nq .== min)], wordle.words[findall(nq .== max)]
    expected = log(wordle.b, length(wordle.words))
    @info "Performance" N min max μ σ best worst expected
end

main(parse(Int, ARGS[1]))
