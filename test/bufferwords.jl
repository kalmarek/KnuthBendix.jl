import KnuthBendix: Words

@testset "Words.BufferWord internals" begin
    @test one(Words.BufferWord{Int}) isa Words.BufferWord{Int}
    @test isone(one(Words.BufferWord{UInt16}))
    @test Words.BufferWord([1, 2, 3]) isa Words.BufferWord{UInt16}
    @test !isone(Words.BufferWord([1, 2, 3]))

    let bw = one(Words.BufferWord{UInt16})
        append!(bw, [1, 2, 3, 4])
        @test bw == [1, 2, 3, 4]
        il = Words.internal_length(bw)
        W = Word(bw)
        Words._growend!(bw, 3)
        @test Words.internal_length(bw) == il + 3
        @test bw == W
        Words._growbeg!(bw, 3)
        @test bw == W
        @test Words.internal_length(bw) == il + 3 + 3

        @test pop!(bw) == 4
        @test bw == [1, 2, 3]
        @test popfirst!(bw) == 1
        @test bw == [2, 3]

        @test Words.internal_length(bw) == il + 3 + 3
    end

    let bw = Words.BufferWord{UInt16}([1, 2, 3, 4], 0, 0)
        @test Words.internal_length(bw) == 4
        W = Word(bw)
        Words._growend!(bw, 4)
        @test bw == W
        @test Words.internal_length(bw) == 8
        Words._growbeg!(bw, 4)
        @test bw == W
        @test Words.internal_length(bw) == 12
        @test Word(bw) == W
    end
end

@testset "Words.BufferWord push/append" begin
    let bw_orig = one(Words.BufferWord{UInt16})
        bw = deepcopy(bw_orig)
        @test push!(bw, 1) == [1]

        bw = deepcopy(bw_orig)
        @test pushfirst!(bw, 1) == [1]

        bw = deepcopy(bw_orig)
        @test prepend!(bw, [1]) == [1]

        bw = deepcopy(bw_orig)
        @test append!(bw, [1]) == [1]
    end

    let bw_orig = Words.BufferWord([2])
        bw = deepcopy(bw_orig)
        @test push!(bw, 1) == [2, 1]

        bw = deepcopy(bw_orig)
        @test pushfirst!(bw, 1) == [1, 2]

        bw = deepcopy(bw_orig)
        @test prepend!(bw, [1]) == [1, 2]

        bw = deepcopy(bw_orig)
        @test append!(bw, [1]) == [2, 1]
    end

    let bw_orig = Words.BufferWord{UInt16}([2], 0, 0)
        bw = deepcopy(bw_orig)
        @test push!(bw, 1) == [2, 1]

        bw = deepcopy(bw_orig)
        @test pushfirst!(bw, 1) == [1, 2]

        bw = deepcopy(bw_orig)
        @test prepend!(bw, [1]) == [1, 2]

        bw = deepcopy(bw_orig)
        @test append!(bw, [1]) == [2, 1]
    end

    let bw_orig = Words.BufferWord{UInt16}([2, 2, 2, 2], 0, 0)
        bw = deepcopy(bw_orig)
        @test push!(bw, 1) == [2, 2, 2, 2, 1]

        bw = deepcopy(bw_orig)
        @test pushfirst!(bw, 1) == [1, 2, 2, 2, 2]

        bw = deepcopy(bw_orig)
        @test prepend!(bw, [1, 1, 1, 1]) == [1, 1, 1, 1, 2, 2, 2, 2]

        bw = deepcopy(bw_orig)
        @test append!(bw, [1, 1, 1, 1]) == [2, 2, 2, 2, 1, 1, 1, 1]
    end
end

abstract_word_conformance_test(Words.BufferWord)
