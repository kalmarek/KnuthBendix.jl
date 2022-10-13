function RWS_Example_5_1()
    Al = Alphabet(['a', 'A', 'b', 'B'])
    KnuthBendix.setinverse!(Al, 'a', 'A')
    KnuthBendix.setinverse!(Al, 'b', 'B')
    a, A, b, B = Word.([i] for i in 1:4)
    ε = one(a)

    R = RewritingSystem(
        [b * a => a * b],
        LenLex(Al, order = ['a', 'A', 'b', 'B']),
    )

    return R
end

RWS_ZxZ() = RWS_Example_5_1()

function RWS_Example_5_2()
    Al = Alphabet(['a', 'A', 'b', 'B'])
    KnuthBendix.setinverse!(Al, 'a', 'A')
    KnuthBendix.setinverse!(Al, 'b', 'B')
    a, A, b, B = Word.([i] for i in 1:4)
    ε = one(a)

    R = RewritingSystem(
        [b * a => a * b],
        LenLex(Al, order = ['a', 'b', 'A', 'B']),
    )

    return R
end

RWS_ZxZ_nonterminating() = RWS_Example_5_2()

function RWS_Example_5_3()
    Al = Alphabet(['a', 'b'])

    a, b = Word.([i] for i in 1:2)
    ε = one(a)

    R = RewritingSystem([a^2 => ε, b^3 => ε, (a * b)^3 => ε], LenLex(Al))

    return R
end

function RWS_Example_5_4()
    Al = Alphabet(['a', 'b', 'B'])
    KnuthBendix.setinverse!(Al, 'b', 'B')

    a, b, B = Word.([i] for i in 1:3)
    ε = one(a)

    R = RewritingSystem([a^2 => ε, b^3 => ε, (a * b)^3 => ε], LenLex(Al))

    return R
end

function RWS_Example_5_5()
    Al = Alphabet([:a, :b, :c, :A, :B, :C])
    KnuthBendix.setinverse!(Al, :c, :C)
    KnuthBendix.setinverse!(Al, :b, :B)
    KnuthBendix.setinverse!(Al, :a, :A)

    a, b, c, A, B, C = [Word([i]) for i in 1:6]
    ε = one(a)

    eqns = [c * a => a * c, c * b => b * c, b * a => a * b * c]

    R = RewritingSystem(
        eqns,
        WreathOrder(
            Al,
            levels = [5, 3, 1, 5, 3, 1],
            order = [:c, :C, :b, :B, :a, :A],
        ),
    )
    return R
end

function RWS_Example_5_5_rec()
    Al = Alphabet([:a, :b, :c, :A, :B, :C])
    KnuthBendix.setinverse!(Al, :c, :C)
    KnuthBendix.setinverse!(Al, :b, :B)
    KnuthBendix.setinverse!(Al, :a, :A)

    a, b, c, A, B, C = [Word([i]) for i in 1:6]
    ε = one(a)

    eqns = [c * a => a * c, c * b => b * c, b * a => a * b * c]

    R = RewritingSystem(
        eqns,
        Recursive{KnuthBendix.Left}(Al, order = [:c, :C, :b, :B, :a, :A]),
    )
    return R
end

function RWS_Example_6_4()
    Al = Alphabet(['a', 'b', 'B'])
    KnuthBendix.setinverse!(Al, 'b', 'B')

    a, b, B = Word.([i] for i in 1:3)
    ε = one(a)
    eqns = [
        a * a => ε,
        b * B => ε,
        b^3 => ε,
        (a * b)^7 => ε,
        (a * b * a * B)^4 => ε,
    ]

    R = RewritingSystem(eqns, LenLex(Al))
    return R
end

function RWS_Example_6_5()
    Al = Alphabet(['a', 'b', 'B'])
    KnuthBendix.setinverse!(Al, 'b', 'B')

    a, b, B = Word.([i] for i in 1:3)
    ε = one(a)
    eqns =
        KnuthBendix.Rule.([
            a * a => ε,
            b * B => ε,
            b^2 => B,
            (B * a)^3 * B => (a * b)^3 * a,
            (b * a * B * a)^2 => (a * b * a * B)^2,
        ])

    R = RewritingSystem(eqns, LenLex(Al))
    return R
end

function RWS_Example_237_abaB(n)
    Al = Alphabet(['a', 'b', 'B'])
    KnuthBendix.setinverse!(Al, 'b', 'B')

    a, b, B = Word.([i] for i in 1:3)
    ε = one(a)

    eqns = [
        b * B => ε,
        B * b => ε,
        a^2 => ε,
        b^3 => ε,
        (a * b)^7 => ε,
        (a * b * a * B)^n => ε,
    ]

    R = RewritingSystem(eqns, LenLex(Al))
    return R
end

RWS_Example_6_6() = RWS_Example_237_abaB(8)

function RWS_Exercise_6_1(n)
    Al = Alphabet(['a', 'b'])

    a, b = Word.([i] for i in 1:2)
    ε = one(a)

    eqns = [a^2 => ε, b^3 => ε, (a * b)^n => ε]

    R = RewritingSystem(eqns, LenLex(Al), bare = true)
    return R
end

function RWS_Closed_Orientable_Surface(n)
    ltrs = String[]
    for i in 1:n
        subscript = join('₀' + d for d in reverse(digits(i)))
        append!(
            ltrs,
            [
                "a" * subscript,
                "A" * subscript,
                "b" * subscript,
                "B" * subscript,
            ],
        )
    end
    Al = Alphabet(ltrs)
    for i in 1:n
        subscript = join('₀' + d for d in reverse(digits(i)))
        KnuthBendix.setinverse!(Al, "a" * subscript, "A" * subscript)
        KnuthBendix.setinverse!(Al, "b" * subscript, "B" * subscript)
    end

    ε = one(Word{UInt16})
    rules = Pair{typeof(ε),typeof(ε)}[]
    word = Int[]

    for i in reverse(1:n)
        x = 4 * i
        append!(word, [x, x - 2, x - 1, x - 3])
    end
    push!(rules, Word(word) => ε)
    R = RewritingSystem(rules, Recursive(Al, order = reverse(ltrs)))

    return R
end

function RWS_Coxeter_group_cube()
    _coxeter_letter(simplex) = Symbol("s", join(simplex, ""))

    function coxeter_alphabet(itr)
        letters = [_coxeter_letter(v) for v in itr]
        inverses = 1:length(letters) # generators are of order 2 i.e. self-inverse
        return KnuthBendix.Alphabet(letters, inverses)
    end

    vertices = [[i] for i in 1:8]
    edges = [
        [1, 2],
        [1, 3],
        [1, 5],
        [2, 4],
        [2, 6],
        [3, 5],
        [3, 7],
        [4, 8],
        [5, 6],
        [5, 7],
        [6, 8],
        [7, 8],
    ] # 3-cube

    A = coxeter_alphabet([edges; vertices])
    weights = [fill(2, length(edges)); fill(1, length(vertices))]
    wtlex = WeightedLex(A, weights = weights)

    S = Dict(v => Word([A[_coxeter_letter(v)]]) for v in vertices)
    for σ in edges
        S[σ] = Word([A[_coxeter_letter(σ)]])
    end

    rels = map(edges) do e
        v1, v2 = [first(e)], [last(e)]
        s1, s2, s12 = S[v1], S[v2], S[e]
        return [ # (1)(2) → (12), (2)(1) → (12)
            s1 * s2 => s12,
            s2 * s1 => s12,
            #(1)(12) → (2)   (2)(12) → (1) (12)(1) → (2) (12)(2) → (1)
            s1 * s12 => s2,
            s2 * s12 => s1,
            s12 * s1 => s2,
            s12 * s2 => s1,
        ]
    end

    rels2 = eltype(eltype(rels))[]
    for e in edges
        for f in edges
            if length(intersect(e, f)) == 1
                edge = union(setdiff(e, f), setdiff(f, e))
                @assert length(edge) == 2
                haskey(S, edge) || reverse!(edge)
                if haskey(S, edge)
                    # (12)(13) → (23)
                    push!(rels2, S[e] * S[f] => S[edge])
                end
            end
        end
    end
    push!(rels, rels2)

    return RewritingSystem(vcat(rels...), wtlex)
end
