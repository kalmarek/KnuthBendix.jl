using KnuthBendix
using Test

@testset "KnuthBendix.jl" begin
   include("words.jl")
   include("alphabets.jl")
   include("orderings.jl")
   include("rewriting.jl")
   include("kbs1.jl")
   include("kbs2.jl")
   include("automata.jl")
   include("rws_examples.jl")
end
