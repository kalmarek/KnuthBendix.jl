@testset "States" begin
    s = KnuthBendix.State{String,Int,String}("AAA", max_degree = 3)
    @test s isa KnuthBendix.State
    t = typeof(s)("BBB", 15, max_degree = 3)
    fail = typeof(s)()

    @test !KnuthBendix.isterminal(s)
    @test !KnuthBendix.isterminal(t)

    @test !KnuthBendix.isfail(s)
    @test !KnuthBendix.isfail(t)
    @test KnuthBendix.isfail(fail)

    @test_throws String KnuthBendix.value(s)

    KnuthBendix.setvalue!(s, "10")
    @test KnuthBendix.isterminal(s)
    @test KnuthBendix.value(s) == "10"

    @test KnuthBendix.id(s) == "AAA"
    @test KnuthBendix.id(t) == "BBB"

    @test KnuthBendix.max_degree(s) == 3
    @test KnuthBendix.degree(s) == 0

    @test !KnuthBendix.hasedge(s, 1)
    @test !KnuthBendix.hasedge(s, 2)
    @test !KnuthBendix.hasedge(s, 3)

    s[2] = t
    @test KnuthBendix.hasedge(s, 2)
    @test KnuthBendix.degree(s) == 1

    s[3] = fail
    @test !KnuthBendix.hasedge(s, 3)
    @test KnuthBendix.degree(s) == 1
    @test !KnuthBendix.iscomplete(s)

    s[1] = t
    @test KnuthBendix.hasedge(s, 1)
    @test KnuthBendix.degree(s) == 2
    @test !KnuthBendix.iscomplete(s)

    s[3] = s
    @test KnuthBendix.hasedge(s, 3)
    @test KnuthBendix.iscomplete(s)
    @test KnuthBendix.degree(s) == 3
    @test s[1] == t
    @test s[2] == t
    @test s[3] == s

    @test sprint(show, s) isa String
    @test sprint(show, [s]) isa String
end

@testset "Automata" begin
    al = KnuthBendix.Alphabet(['a', 'A', 'b', 'B'])
    KnuthBendix.set_inversion!(al, 'a', 'A')
    KnuthBendix.set_inversion!(al, 'b', 'B')

    a, A, b, B = (Word([i]) for i in 1:length(al))
    ε = one(a)
    lenlexord = KnuthBendix.LenLex(al)

    testword =
        Word([1, 1, 1, 2, 2, 2, 3, 4, 2, 2, 3, 3, 3, 4, 4, 4, 4, 3, 4, 3, 4, 1])

    rs = KnuthBendix.RewritingSystem([A => ε, B => ε], lenlexord)
    ia = KnuthBendix.IndexAutomaton(rs)
    @test KnuthBendix.rewrite_from_left(testword, rs) ==
          KnuthBendix.rewrite_from_left(testword, ia) ==
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
    )
    ia = KnuthBendix.IndexAutomaton(rs)

    @test !isempty(ia)

    @test KnuthBendix.rewrite_from_left(testword, rs) ==
          KnuthBendix.rewrite_from_left(testword, ia)

    w = Word([1, 3, 4, 1, 4, 4, 1, 1, 4, 2, 3, 2, 4, 2, 2, 3, 1, 2, 1])
    @test KnuthBendix.rewrite_from_left(w, rs) ==
          KnuthBendix.rewrite_from_left(w, ia)
end
