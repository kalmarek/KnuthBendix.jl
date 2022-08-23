@testset "KBS1" begin
    Al = Alphabet(['a', 'A', 'b', 'B'])
    KnuthBendix.setinverse!(Al, 'a', 'A')
    KnuthBendix.setinverse!(Al, 'b', 'B')
    lenlexord = LenLex(Al)

    a, A, b, B = [Word([i]) for i in 1:4]
    ε = one(a)

    rs = RewritingSystem([b * a => a * b], lenlexord)
    rsc = RewritingSystem(
        [b * a => a * b, b * A => A * b, B * a => a * B, B * A => A * B],
        lenlexord,
    )
    @test KnuthBendix.irreduciblesubsystem(rsc) ==
          [a * A, A * a, b * B, B * b, b * a, b * A, B * a, B * A]

    rls = collect(KnuthBendix.rules(rs))

    KnuthBendix.forceconfluence!(rs, rls[5], rls[1])
    @test collect(KnuthBendix.rules(rs)) ==
          KnuthBendix.Rule.([
        a * A => ε,
        A * a => ε,
        b * B => ε,
        B * b => ε,
        b * a => a * b,
        a * b * A => b,
    ])

    KnuthBendix.deriverule!(rs, B * a * b, a)
    @test collect(KnuthBendix.rules(rs)) ==
          KnuthBendix.Rule.([
        a * A => ε,
        A * a => ε,
        b * B => ε,
        B * b => ε,
        b * a => a * b,
        a * b * A => b,
        B * a * b => a,
    ])

    @test Set(KnuthBendix.rules(KnuthBendix.knuthbendix1(rs))) ==
          Set(KnuthBendix.rules(rsc))

    Bl = KnuthBendix.Alphabet(['a', 'b', 'B'])
    KnuthBendix.setinverse!(Bl, 'a', 'a')
    KnuthBendix.setinverse!(Bl, 'b', 'B')
    lenlexordB = LenLex(Bl)

    a, b, B = [Word([i]) for i in 1:3]
    ε = one(a)

    rsb = RewritingSystem(
        [
            b * b * b => ε,
            (a * b)^3 => ε,
            b * b => B,
            b * a * b * a * b => a,
            a * b * a * b * a => B,
            B * B => b,
            b * a * b * a => a * B,
            a * b * a * b => B * a,
            b * a * b => a * B * a,
            B * a * B => a * b * a,
            B * a * b * a => b * a * B,
            a * b * a * B => B * a * b,
            a * B * a * b => b * a * B,
            b * a * B * a => B * a * b,
        ],
        lenlexordB,
        bare = false,
    )

    @test KnuthBendix.irreduciblesubsystem(rsb) == [
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
