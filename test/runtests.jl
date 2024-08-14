using KnuthBendix
using Test
using Documenter
import KnuthBendix as KB
import KnuthBendix.Automata

include("abstract_words.jl")

@testset "KnuthBendix.jl" begin
    include("packed_vector.jl")
    include("words.jl")
    include("bufferwords.jl")
    include("alphabets.jl")
    include("orderings.jl")
    include("rewriting.jl")
    include("automata.jl")
    include("backtrack.jl")
    include("kbs1.jl")
    include("kbs.jl")

    include("test_examples.jl")

    include("gapdoc_examples.jl")
    include("kbmag_parsing.jl")

    if !haskey(ENV, "CI") || v"1.6" ≤ VERSION < v"1.7"
        DocMeta.setdocmeta!(
            KnuthBendix,
            :DocTestSetup,
            :(using KnuthBendix; import Base.Order: lt);
            recursive = true,
        )
        doctest(KnuthBendix)
    end
end
