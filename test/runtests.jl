using KnuthBendix
using Test

include("abstract_words.jl")

@testset "KnuthBendix.jl" begin
   include("words.jl")
   include("bufferwords.jl")

   include("alphabets.jl")
   include("orderings.jl")
   include("rewriting.jl")
   include("kbs1.jl")
   include("kbs2.jl")
   include("automata.jl")
   include("rws_examples.jl")
end
