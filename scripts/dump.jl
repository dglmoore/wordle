using DrWatson

include(srcdir("wordle.jl"))

function main(n)
    wordle = Wordle(n)
    open("dump.dat", "w") do io
        for w in wordle.A
            write(io, w)
        end
    end
end

main(5)
