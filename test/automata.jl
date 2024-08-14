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

@testset "Construction & modification of PrefixAutomaton" begin
    al = KB.Alphabet([:a, :A, :b, :B])
    KB.setinverse!(al, :a, :A)
    KB.setinverse!(al, :b, :B)

    a, A, b, B = [Word([i]) for i in 1:length(al)]
    ε = one(a)
    lenlex = KB.LenLex(al)

    rules = KB.rules(Word{UInt16}, lenlex)
    push!(rules, KB.Rule(a * b, b * a, lenlex))

    let pfxA = Automata.PrefixAutomaton(lenlex, empty(rules))
        added, _ = Automata.add_direct_path!(pfxA, a * A, -1)
        @test added
        added, _ = Automata.add_direct_path!(pfxA, a * A * b, -2)
        @test !added
        added, _ = Automata.add_direct_path!(pfxA, A * a, -2)
        @test added
        added, _ = Automata.add_direct_path!(pfxA, b * B, -3)
        @test added
        added, _ = Automata.add_direct_path!(pfxA, B * b, -4)
        @test added
        added, _ = Automata.add_direct_path!(pfxA, b * a, -5)
        @test added
        @test !first(Automata.add_direct_path!(pfxA, b * a * B, -10))
    end

    @testset "Incremental construction of PrefixAutomaton for Z×Z" begin
        pfxA = Automata.PrefixAutomaton(lenlex, copy(rules))
        work = KB.Workspace(pfxA, KB.Settings())
        w = a * b * A

        @test !KB.isreducible(w, pfxA)
        pfxA_dc = deepcopy(pfxA)
        st = KB.reduce_once!(pfxA_dc, work)
        @test st.changed == 0 && st.deactivated == 0
        @test pfxA.rwrules == pfxA_dc.rwrules

        nr1 = KB.Rule(a * b * A, b, lenlex)
        push!(pfxA, nr1)
        @test KB.__rawrules(pfxA)[end] === nr1

        @test KB.isreducible(w, pfxA)
        @test !KB.isreducible(w, pfxA, skipping = 6)
        pfxA_dc = deepcopy(pfxA)
        st = KB.reduce_once!(pfxA_dc, work)
        @test st.changed == 0 && st.deactivated == 0
        @test pfxA.rwrules == pfxA_dc.rwrules

        nr2 = KB.Rule(B * a * b, a, lenlex)
        push!(pfxA, nr2)
        @test KB.__rawrules(pfxA)[end] === nr2

        @test KB.isreducible(w, pfxA)
        @test !KB.isreducible(w, pfxA, skipping = 6)
        pfxA_dc = deepcopy(pfxA)
        st = KB.reduce_once!(pfxA_dc, work)
        @test st.changed == 0 && st.deactivated == 0
        @test pfxA.rwrules == pfxA_dc.rwrules

        nr3 = KB.Rule(b * A, A * b, lenlex)
        push!(pfxA, nr3)
        @test KB.__rawrules(pfxA)[end] === nr3

        @test KB.isreducible(w, pfxA)
        @test KB.isreducible(w, pfxA, skipping = 6)
        pfxA_dc = deepcopy(pfxA)
        st = KB.reduce_once!(pfxA_dc, work)
        @test st.changed == 0 && st.deactivated == 1
        @test length(pfxA.rwrules) == count(KB.isactive, pfxA_dc.rwrules) + 1

        @test !KB.isreducible(B * a * b, pfxA, skipping = 7)
        nr4 = KB.Rule(B * a, a * B, lenlex)
        push!(pfxA, nr4)
        @test KB.__rawrules(pfxA)[end] === nr4
        @test KB.isreducible(B * a * b, pfxA, skipping = 7)

        pfxA_dc = deepcopy(pfxA)
        st = KB.reduce_once!(pfxA_dc, work)
        @test st.changed == 0 && st.deactivated == 2
        @test length(pfxA.rwrules) == count(KB.isactive, pfxA_dc.rwrules) + 2

        nr5 = KB.Rule(B * A * b, A, lenlex)
        push!(pfxA, nr5)
        @test KB.__rawrules(pfxA)[end] === nr5
        @test KB.isreducible(B * A * b, pfxA)
        @test !KB.isreducible(B * A * b, pfxA, skipping = 10)

        pfxA_dc = deepcopy(pfxA)
        st = KB.reduce_once!(pfxA_dc, work)
        @test st.changed == 0 && st.deactivated == 2
        @test length(pfxA.rwrules) == count(KB.isactive, pfxA_dc.rwrules) + 2

        nr6 = KB.Rule(a * B * A, B, lenlex)
        push!(pfxA, nr6)
        @test KB.__rawrules(pfxA)[end] === nr6

        nr7 = KB.Rule(B * A, A * B, lenlex)
        push!(pfxA, nr7)
        @test KB.__rawrules(pfxA)[end] === nr7

        pfxA_dc = deepcopy(pfxA)
        st = KB.reduce_once!(pfxA_dc, work)
        @test st.changed == 0 && st.deactivated == 4
        @test count(KB.isactive, pfxA_dc.rwrules) == 8

        @test [i for (i, r) in pairs(pfxA_dc.rwrules) if KB.isactive(r)] == [1, 2, 3, 4, 5, 8, 9, 12]
    end

    @testset "Reducing PrefixAutomaton" begin
        al = KB.Alphabet([:a, :A, :b, :B])
        KB.setinverse!(al, :a, :A)
        KB.setinverse!(al, :b, :B)
        a, A, b, B = [Word([i]) for i in 1:length(al)]

        lenlex = KB.LenLex(al)
        rules = KB.rules(Word{UInt16}, lenlex)
        push!(rules, KB.Rule(a * b * b * b * a, one(a), lenlex))
        push!(rules, KB.Rule(a * b * b * b * A, one(a), lenlex))

        pfxA = KB.PrefixAutomaton(lenlex, deepcopy(rules))
        work = KB.Workspace(pfxA, KB.Settings())
        pfxA_dc = deepcopy(pfxA)
        st = KB.reduce_once!(pfxA_dc, work)
        @test st.changed == 0 && st.deactivated == 0

        new_rule = KB.Rule(b * b * b, one(b), lenlex)
        push!(pfxA, new_rule)
        pfxA_dc = deepcopy(pfxA)
        st = KB.reduce_once!(pfxA_dc, work)
        @test st.changed == 1 && st.deactivated == 1
        @test count(KB.isactive, pfxA_dc.rwrules) + 1 == length(pfxA.rwrules)
        st = KB.reduce_once!(pfxA_dc, work)
        @test st.changed == 0 && st.deactivated == 0

        active_rules = filter(KB.isactive, pfxA_dc.rwrules)

        @test active_rules == [
            rules[1:4]
            [
                KB.Rule(a * a, one(a), lenlex),
                KB.Rule(b * b * b, one(b), lenlex),
            ]
        ]
    end
end
@testset "Automata rewriting" begin
    al = KB.Alphabet(['a', 'A', 'b', 'B'])
    KB.setinverse!(al, 'a', 'A')
    KB.setinverse!(al, 'b', 'B')

    a, A, b, B = (Word([i]) for i in 1:length(al))
    ε = one(a)
    lenlexord = KB.LenLex(al)

    testword =
        Word([1, 1, 1, 2, 2, 2, 3, 4, 2, 2, 3, 3, 3, 4, 4, 4, 4, 3, 4, 3, 4, 1])

    rs =
        KB.RewritingSystem([(A, ε), (B, ε)], lenlexord, reduced = true)
    ia = KB.IndexAutomaton(rs)
    @test KB.rewrite(testword, rs) ==
          KB.rewrite(testword, ia) ==
          Word([1])

    rs = KB.RewritingSystem(
        [
            (a * A, ε),
            (A * a, ε),
            (b * B, ε),
            (B * b, ε),
            (b * a, a * b),
            (b * A, A * b),
            (B * a, a * B),
            (B * A, A * B),
        ],
        lenlexord,
        reduced = true,
    )
    ia = KB.IndexAutomaton(rs)

    @test !isempty(ia)

    @test KB.rewrite(testword, rs) == KB.rewrite(testword, ia)

    w = Word([1, 3, 4, 1, 4, 4, 1, 1, 4, 2, 3, 2, 4, 2, 2, 3, 1, 2, 1])
    @test KB.rewrite(w, rs) == KB.rewrite(w, ia)

    @test sprint(show, ia) isa String
end
