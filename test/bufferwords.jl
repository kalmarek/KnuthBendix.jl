import KnuthBendix: KnuthBendix.BufferWord

@testset "KnuthBendix.BufferWord internals" begin
    @test KnuthBendix.BufferWord() isa KnuthBendix.BufferWord{UInt16}
    @test isone(KnuthBendix.BufferWord())
    @test KnuthBendix.BufferWord([1,2,3]) isa KnuthBendix.BufferWord{UInt16}
    @test !isone(KnuthBendix.BufferWord([1,2,3]))

    let bw = KnuthBendix.BufferWord();
        append!(bw, [1,2,3,4])
        il = KnuthBendix.internal_length(bw)
        W = Word(bw)
        KnuthBendix._growatend!(bw, 3)
        @test KnuthBendix.internal_length(bw) == il + 3
        @test bw == W
        KnuthBendix._growatbeg!(bw, 3)
        @test bw == W
        @test KnuthBendix.internal_length(bw) == il + 3 + 3

        @test pop!(bw) == 4
        @test bw == [1,2,3]
        @test popfirst!(bw) == 1
        @test bw == [2,3]

        @test KnuthBendix.internal_length(bw) == il + 3 + 3
    end


    let bw = KnuthBendix.BufferWord{UInt16}([1,2,3,4], 0, 0)
        @test KnuthBendix.internal_length(bw) == 4
        W = Word(bw)
        KnuthBendix._growatend!(bw, 4);
        @test bw == W
        @test KnuthBendix.internal_length(bw) == 8
        KnuthBendix._growatbeg!(bw, 4);
        @test bw == W
        @test KnuthBendix.internal_length(bw) == 12
        @test Word(bw) == W
    end
end

@testset "KnuthBendix.BufferWord push/append" begin

    let bw_orig = KnuthBendix.BufferWord()

        bw = deepcopy(bw_orig)
        @test push!(bw,1) == [1]

        bw = deepcopy(bw_orig)
        @test pushfirst!(bw,1) == [1]

        bw = deepcopy(bw_orig)
        @test prepend!(bw,[1]) == [1]

        bw = deepcopy(bw_orig)
        @test append!(bw,[1]) == [1]
    end

    let bw_orig = KnuthBendix.BufferWord([2])

        bw = deepcopy(bw_orig)
        @test push!(bw,1) == [2,1]

        bw = deepcopy(bw_orig)
        @test pushfirst!(bw,1) == [1,2]

        bw = deepcopy(bw_orig)
        @test prepend!(bw,[1]) == [1, 2]

        bw = deepcopy(bw_orig)
        @test append!(bw,[1]) == [2,1]
    end

    let bw_orig = KnuthBendix.BufferWord{UInt16}([2], 0, 0)

        bw = deepcopy(bw_orig)
        @test push!(bw,1) == [2,1]

        bw = deepcopy(bw_orig)
        @test pushfirst!(bw,1) == [1,2]

        bw = deepcopy(bw_orig)
        @test prepend!(bw,[1]) == [1, 2]

        bw = deepcopy(bw_orig)
        @test append!(bw,[1]) == [2,1]
    end

    let bw_orig = KnuthBendix.BufferWord{UInt16}([2,2,2,2], 0, 0)

        bw = deepcopy(bw_orig)
        @test push!(bw,1) == [2,2,2,2,1]

        bw = deepcopy(bw_orig)
        @test pushfirst!(bw,1) == [1,2,2,2,2]

        bw = deepcopy(bw_orig)
        @test prepend!(bw,[1,1,1,1]) == [1,1,1,1,2,2,2,2]

        bw = deepcopy(bw_orig)
        @test append!(bw,[1,1,1,1]) == [2,2,2,2,1,1,1,1]
    end
end

abstract_word_conformance_test(KnuthBendix.BufferWord)
