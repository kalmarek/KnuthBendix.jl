using PrecompileTools
@setup_workload begin
    @compile_workload begin
        n = 6
        Al = Alphabet(['a', 'b', 'B'])
        setinverse!(Al, 'b', 'B')

        a, b, B = Word.([i] for i in 1:3)
        ε = one(a)

        eqns = [
            (b * B, ε),
            (B * b, ε),
            (a^2, ε),
            (b^3, ε),
            ((a * b)^7, ε),
            ((a * b * a * B)^n, ε),
        ]

        R = RewritingSystem(eqns, LenLex(Al))
        knuthbendix(R)
    end
end
