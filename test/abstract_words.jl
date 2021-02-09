function abstract_word_constructors_test(::Type{Wo}) where Wo

    @testset "constructors: $Wo" begin

        @test Wo([1,2]) isa Wo
        @test Wo([1,2]) isa KnuthBendix.AbstractWord
        @test Wo{Int}([1,2]) isa Wo{Int}

        @test one(Wo{Int}) isa KnuthBendix.AbstractWord{Int}
        @test one(Wo{Int}) isa Wo{Int}

        @test similar(Wo([1,2])) isa Wo

        @test Word(Wo([1,2])) isa Word
        @test Wo(Word([1,2])) isa Wo
    end
end

function abstract_word_basic_functions_test(::Type{Wo}) where Wo

    @testset "basic functionality: $Wo" begin
        @test one(Wo{Int}) isa Wo
        @test one(Wo{UInt16}) isa Wo

        w = Wo([1,2])
        W = Word{Int}([1,2])

        @test W  == w
        @test W !== w
        @test one(w) == one(W)
        @test !isone(w)
        @test !isone(W)
        @test isone(one(w))
        @test isone(one(W))

        @test hash(w) isa UInt
        @test hash(w) == hash(W)
        @test hash(w, UInt(1)) != hash(w, UInt(0))
        @test hash(w) != hash(one(w))

        @test length(Set([w,W])) == 1

        @test deepcopy(w) == w
        @test deepcopy(w) !== w
    end
end

function abstract_word_push_pop_append_test(::Type{Wo}) where Wo

    @testset "push!,pop!,append!,prepend!: $Wo" begin
        w = one(Wo{UInt16}); W = deepcopy(w);

        @test push!(w, 1) == Wo([1])
        @test w == Wo([1]) && isone(W)
        W = deepcopy(w)

        @test append!(w, [1,2]) == Wo([1,1,2])
        @test w == Wo([1,1,2]) && W == Wo([1])
        W = deepcopy(w)

        @test pop!(w) == 2
        @test w == Wo([1,1]) && W == Wo([1,1,2])
        W = deepcopy(w)

        @test pushfirst!(w, 3) == Wo([3,1,1])
        @test w == Wo([3,1,1]) && W == Wo([1,1])
        W == deepcopy(w)

        @test popfirst!(w) == 3
        @test w == Wo([1,1]) && W == Wo([1,1])
        W == deepcopy(w)

        @test prepend!(w,[1,2]) == Wo([1,2,1,1])
        @test w == Wo([1,2,1,1]) && W == Wo([1,1])
        W = deepcopy(w)

        @test resize!(w, 3) == Wo([1,2,1])
        @test w == Wo([1,2,1]) && W == Wo([1,2,1,1])
        W = deepcopy(w)

        @test resize!(w, 30) isa Wo{eltype(w)}
        @test length(w) == 30 && length(W) == 3
        @test resize!(w, 3) == W
        @test w == W

        @test_throws ArgumentError resize!(w, -4)
    end
end


function abstract_word_indexing_test(::Type{Wo}) where Wo

    @testset "indexing: $Wo" begin
        w = Wo([1,2]); W = deepcopy(w);

        @test collect(W) isa Vector{eltype(w)}
        @test collect(push!(W, 3)) == push!(collect(w), 3)
        @test W[end] == 3

        WW = deepcopy(W)

        @test collect(pushfirst!(W, 4)) == pushfirst!(collect(WW), 4)
        @test W[1] == 4

        @test W[2:3] isa Wo
        @test W[1:1] == Wo([4])
        @test W[end:end] isa Wo
        @test W[end:end] == Wo([3])
        @test W[2:2][1] == W[2]

        W_arr = collect(W)
        lw = length(W_arr)

        @test append!(W, Wo([6])) == Wo([W_arr; 6])
        @test prepend!(W, Wo([5])) == Wo([5; W_arr; 6])
        @test collect(W) isa Vector{eltype(w)}
        @test collect(W) == [5; W_arr; 6]
        @test W[1] == 5
        @test length(W) == lw + 2
        @test_throws BoundsError W[-1]
        @test_throws BoundsError W[lw+3]

        @test @view(W[2:3]) isa KnuthBendix.AbstractWord
    end
end

function abstract_word_arithmetic_test(::Type{Wo}) where Wo

    @testset "arithmetic: $Wo" begin

        @test Wo([1, 2]) * Wo([2, 3]) == Wo([1, 2, 2, 3])
        @test Wo([1, 2]) * Wo{Int}([2, 3]) == Wo{Int}([1, 2, 2, 3])
        @test Wo{Int}([1, 2]) * Wo([1, 2]) == Wo{Int}([1, 2, 1, 2])

        w = Wo([1,2])
        @test w^2 == Wo([collect(w); collect(w)])
        w_arr = collect(w)

        u1 = Word([1,2,3,4])
        u2 = Word([1,2])
        u3 = Word([4,1,2,3,4])
        u4 = Word([1])
        u5 = Word([2,3,4])

        @test KnuthBendix.longestcommonprefix(u1, u2) == 2
        @test KnuthBendix.longestcommonprefix(u1, u1) == 4
        @test KnuthBendix.lcp(u3, u2) == 0

        @test  KnuthBendix.isprefix(u2, u1)
        @test !KnuthBendix.isprefix(u2, u3)
        @test  KnuthBendix.issuffix(u5, u3)
        @test !KnuthBendix.issuffix(u5, u2)

        @test occursin(u2, u1) == true
        @test occursin(u2, u3) == true
        @test occursin(u1, u2) == false
        @test occursin(u4, u2) == true

        @test findnext(isequal(2), u3, 1)  == 3
        @test findnext(isequal(2), u3, 4)  === nothing
    end
end

function abstract_word_conformance_test(::Type{Wo}) where Wo
    @testset "KnuthBendix.AbstractWord conformance test: $Wo" begin
        abstract_word_constructors_test(Wo)
        abstract_word_push_pop_append_test(Wo)
        abstract_word_basic_functions_test(Wo)
        abstract_word_indexing_test(Wo)
        abstract_word_arithmetic_test(Wo)
    end
end
