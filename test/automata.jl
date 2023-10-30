import KnuthBendix.Automata

@testset "States" begin
    S = Automata.State{Symbol,UInt32,String}
    @test S() isa Automata.State

    fail = S(Vector{S}(undef, 3), :fail, 0)

    s = Automata.State(fail, :AAA, 10)
    @test s isa Automata.State
    @test Automata.id(s) == :AAA

    @test Automata.max_degree(s) == 3
    @test Automata.degree(s) == 3

    @test Automata.hasedge(s, 1)
    @test Automata.hasedge(s, 2)
    @test Automata.hasedge(s, 3)
    @test s[1] == fail
    @test s[2] === s[3] === fail

    @test_throws UndefRefError Automata.value(s)
    Automata.setvalue!(s, "10")
    @test Automata.value(s) == "10"

    t = S(:BBB, 15, max_degree = 3)
    @test Automata.id(t) == :BBB
    @test Automata.max_degree(t) == 3
    @test Automata.degree(t) == 0

    @test all(i -> !Automata.hasedge(t, i), 1:3)

    t[1] = t
    @test Automata.hasedge(t, 1)
    @test Automata.degree(t) == 1

    t[2] = s
    @test Automata.hasedge(t, 2)
    @test Automata.degree(t) == 2

    t[3] = fail
    @test Automata.hasedge(t, 3)
    @test Automata.degree(t) == 3

    @test t[1] == t
    @test t[2] == s
    @test t[3] == fail

    @test sprint(show, s) isa String
    @test sprint(show, MIME"text/plain"(), s) isa String

    @test sprint(show, t) isa String
    @test sprint(show, MIME"text/plain"(), t) isa String

    @test sprint(show, fail) isa String
    @test sprint(show, MIME"text/plain"(), fail) isa String
end

@testset "Automata" begin
    al = KnuthBendix.Alphabet(['a', 'A', 'b', 'B'])
    KnuthBendix.setinverse!(al, 'a', 'A')
    KnuthBendix.setinverse!(al, 'b', 'B')

    a, A, b, B = (Word([i]) for i in 1:length(al))
    ε = one(a)
    lenlexord = KnuthBendix.LenLex(al)

    testword =
        Word([1, 1, 1, 2, 2, 2, 3, 4, 2, 2, 3, 3, 3, 4, 4, 4, 4, 3, 4, 3, 4, 1])

    rs =
        KnuthBendix.RewritingSystem([A => ε, B => ε], lenlexord, reduced = true)
    ia = KnuthBendix.IndexAutomaton(rs)
    @test KnuthBendix.rewrite(testword, rs) ==
          KnuthBendix.rewrite(testword, ia) ==
          Word([1])

    rs = KnuthBendix.RewritingSystem(
        [
            a * A => ε,
            A * a => ε,
            b * B => ε,
            B * b => ε,
            b * a => a * b,
            b * A => A * b,
            B * a => a * B,
            B * A => A * B,
        ],
        lenlexord,
        reduced = true,
    )
    ia = KnuthBendix.IndexAutomaton(rs)

    @test !isempty(ia)

    @test KnuthBendix.rewrite(testword, rs) == KnuthBendix.rewrite(testword, ia)

    w = Word([1, 3, 4, 1, 4, 4, 1, 1, 4, 2, 3, 2, 4, 2, 2, 3, 1, 2, 1])
    @test KnuthBendix.rewrite(w, rs) == KnuthBendix.rewrite(w, ia)

    @test sprint(show, ia) isa String
end
