@testset "KBS1" begin

    Al = Alphabet(['a', 'A', 'b', 'B'])
    KnuthBendix.set_inversion!(Al, 'a', 'A')
    KnuthBendix.set_inversion!(Al, 'b', 'B')
    lenlexord = LenLex(Al)

    a, A, b, B = [Word([i]) for i in 1:4]
    ε = one(a)

    rs = RewritingSystem([b * a => a * b], lenlexord)
    rsc = RewritingSystem(
        [b * a => a * b, b * A => A * b, B * a => a * B, B * A => A * B],
        lenlexord,
    )
    @test KnuthBendix.getirreduciblesubsystem(rsc) ==
          [a * A, A * a, b * B, B * b, b * a, b * A, B * a, B * A]

    KnuthBendix.forceconfluence!(rs, 5, 1)
    @test KnuthBendix.rules(rs) ==
          [a * A => ε, A * a => ε, b * B => ε, B * b => ε, b * a => a * b, a * b * A => b]

    KnuthBendix.deriverule!(rs, B * a * b, a)
    @test KnuthBendix.rules(rs) == [
        a * A => ε,
        A * a => ε,
        b * B => ε,
        B * b => ε,
        b * a => a * b,
        a * b * A => b,
        B * a * b => a,
    ]


    Bl = KnuthBendix.Alphabet(['a', 'b', 'B'])
    KnuthBendix.set_inversion!(Bl, 'a', 'a')
    KnuthBendix.set_inversion!(Bl, 'b', 'B')
    lenlexordB = LenLex(Bl)

    a, b, B = [Word([i]) for i in 1:3]

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
    )

    @test KnuthBendix.getirreduciblesubsystem(rsb) == [
        a * a,
        b * B,
        B * b,
        b * b,
        B * B,
        b * a * b,
        B * a * B,
        B * a * b * a,
        a * b * a * B,
        a * B * a * b,
        b * a * B * a,
    ]
end
