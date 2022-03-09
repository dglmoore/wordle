using DrWatson, Markdown

include(srcdir("wordle.jl"))

function loadweb(n)
    filename = datadir("web_$n.jld2")
    if isfile(filename)
        @info "Loading Web($n) from file"
        web = load(filename, "web")
        @info "done"
        web
    else
        @info "Precomputing Web($n)"
        web = Web(n)
        @info "Saving to $filename"
        save(filename, Dict("web" => web))
        @info "done"
        web
    end
end

function getinput(n, prompt::String=">")
    while true
        print(prompt, ' ')
        try
            input = strip(readline(stdin))
            if input == "q" || input == "quit"
                println("Goodbye")
                exit(0)
            end
            chars = collect(input)
            if length(chars) < n
                error("too few characters")
            elseif length(chars) > n
                error("too many characters")
            end
            return map(x -> Match(parse(Int, x)), chars)
        catch err
            println("error: $(err.msg)")
        end
    end
end

const usage=md"""
# Wordle Solver

The solver will print out a word and prompt you for the wordle result. For each letter in the word,
enter a

  - 0 if the letter is not in the word
  - 1 if the letter is in the word, but not in that place
  - 2 if the letter is in the right place

## Example
Suppose the target word is "apple", and the solver guesses "plane". Then your input should be
```
plane
> 11102
```

**Note:** If you want to quit early, just enter "q"
"""

function main()
    n = isempty(ARGS) ? 5 : parse(Int, ARGS[1])

    if n < 2
        println("words must be at least length 2")
        exit(1)
    end

    @time web = Web(n)

    display(usage)
    println("\n")

    while true
        guesses = Guess[]
        count = 0

        while true
            count += 1
            g = bestguess(web, guesses...)
            if iszero(g.entropy)
                println("$(g.word); final guess after $count guesses")
                break
            elseif isinf(g.entropy)
                println("Giving up after $count guesses")
                break
            else
                println(g.word)
            end

            res = getinput(length(g.word))

            guess = Guess(g.word, res)
            if guess.code == 3^length(g.word)
                println("won after $count guesses")
                break
            end

            push!(guesses, guess)
        end

        println("\nPlay again?")
        print("> ")
        response = strip(readline(stdin))
        if response == "y" || response == "yes"
            continue
        else
            break
        end
    end
end

main()
