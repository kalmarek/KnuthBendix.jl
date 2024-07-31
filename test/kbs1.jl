@testset "KBPlain" begin
    Al = Alphabet([:a, :A, :b, :B])
    KB.setinverse!(Al, :a, :A)
    KB.setinverse!(Al, :b, :B)
    lenlexord = LenLex(Al)

    a, A, b, B = [Word([i]) for i in 1:4]
    ε = one(a)

    rs = RewritingSystem([(b * a, a * b)], lenlexord)
    rsc = RewritingSystem(
        [(b * a, a * b), (b * A, A * b), (B * a, a * B), (B * A, A * B)],
        lenlexord,
    )
    @test KB.irreducible_subsystem(rsc) ==
          [a * A, A * a, b * B, B * b, b * a, b * A, B * a, B * A]

    rls = collect(KB.rules(rs))

    KB.forceconfluence!(rs, rls[5], rls[1])
    @test collect(KB.rules(rs)) ==
          KB.Rule.([
        a * A => ε,
        A * a => ε,
        b * B => ε,
        B * b => ε,
        b * a => a * b,
        a * b * A => b,
    ])

    KB.deriverule!(rs, B * a * b, a)
    @test collect(KB.rules(rs)) ==
          KB.Rule.([
        a * A => ε,
        A * a => ε,
        b * B => ε,
        B * b => ε,
        b * a => a * b,
        a * b * A => b,
        B * a * b => a,
    ])

    let alg = KB.KBPlain(), sett = KB.Settings(alg; verbosity = 0)
        rws = knuthbendix(sett, rs)
        @test Set(KB.rules(rws)) == Set(KB.rules(rsc))
    end

    Bl = KB.Alphabet(['a', 'b', 'B'])
    KB.setinverse!(Bl, 'a', 'a')
    KB.setinverse!(Bl, 'b', 'B')
    lenlexordB = LenLex(Bl)

    a, b, B = [Word([i]) for i in 1:3]
    ε = one(a)

    rsb = RewritingSystem(
        [
            (b * b * b, ε),
            ((a * b)^3, ε),
            (b * b, B),
            (b * a * b * a * b, a),
            (a * b * a * b * a, B),
            (B * B, b),
            (b * a * b * a, a * B),
            (a * b * a * b, B * a),
            (b * a * b, a * B * a),
            (B * a * B, a * b * a),
            (B * a * b * a, b * a * B),
            (a * b * a * B, B * a * b),
            (a * B * a * b, b * a * B),
            (b * a * B * a, B * a * b),
        ],
        lenlexordB,
    )

    @test KB.irreducible_subsystem(rsb) == [
        a * a,
        b * B,
        B * b,
        b * b,
        B * a * B,
        b * a * b,
        B * B,
        b * a * B * a,
        B * a * b * a,
    ]
end
