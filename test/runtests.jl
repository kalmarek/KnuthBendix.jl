using KnuthBendix
using Test
using Documenter

include("abstract_words.jl")

@testset "KnuthBendix.jl" begin
    include("words.jl")
    include("bufferwords.jl")
    include("alphabets.jl")
    include("orderings.jl")
    include("rewriting.jl")
    include("automata.jl")
    include("backtrack.jl")
    include("kbs1.jl")
    include("kbs.jl")

    include("rws_examples.jl")
    include("test_examples.jl")

    include("kbmag_parsing.jl")

    DocMeta.setdocmeta!(
        KnuthBendix,
        :DocTestSetup,
        :(using KnuthBendix; import Base.Order: lt);
        recursive = true,
    )
    doctest(KnuthBendix)
end
