"""
    test1!(u::Word, v::Word, rs::RewritingSystem, o::Ordering)
Adds a rule to a rewriting system (if necessary) that insures that there is
a word derivable form two given words using the rules in rewriting system.
See [Sims, p. 69].
"""
function test1!(u::Word, v::Word, rs::RewritingSystem, o::Ordering)
    a = rewrite_from_left(u, rs)
    b = rewrite_from_left(v, rs)
    if a != b
        lt(o, a, b) ? push!(rs, b=>a) : push!(rs, a=>b)
    end
end

"""
    overlap1!(i::Integer, j::Integer, rs::RewritingSystem, o::Ordering)
Checks the overlaps of right sides of rules at position i and j in the rewriting
system in which rule at i occurs at the beginning of the word. Adds new rules
if failures of local confluence are found. See [Sims, p. 69].
"""
function overlap1!(i::Integer, j::Integer, rs::RewritingSystem, o::Ordering)
    for k in 1:length(rs[i].first)
        a = Word(rs[i].first[1:end-k])
        b = Word(rs[i].first[end-k+1:end])
        n = lcp(b, rs[j].first)
        if isone(Word(b[n+1:end])) || isone(Word(rs[j].first[n+1:end]))
            test1!(a * rs[j].second * Word(b[n+1:end]), rs[i].second * Word(rs[j].first[n+1:end]), rs, o)
        end
    end
end

"""
    getirrsubsys(rs::RewritingSystem)
Returns a list of right sides of rules from rewriting system of which all the
proper subwords are irreducible with respect to this rewriting system.
"""
function getirrsubsys(rs::RewritingSystem)
    rsides = []
    for rule in rs
        ok = true
        n = length(rule.first)
        if n > 2
            for j in 2:(n-1)
                w = Word(rule.first[1:j])
                rw = rewrite_from_left(w, rs)
                (w == rw) || (ok=false; break)
            end
            for i in 2:(n-1)
                ok || break
                for j in (i+1):n
                    w = Word(rule.first[i:j])
                    rw = rewrite_from_left(w, rs)
                    (w == rw) || (ok=false; break)
                end
            end
        end
        ok && push!(rsides, rule.first)
    end
    return rsides
end

"""
    kbs1(rs::RewritingSystem, o::Ordering)
Implements a Knuth-Bendix algorithm that yields reduced, confluent rewriting
system. See [Sims, p.68].

Warning: termination may not occur.
"""
function kbs1(rs::RewritingSystem, o::Ordering)
    i = 1
    ss = zero(rs)

    for rule in rs
        test1!(rule.first, rule.second, ss, o)
    end
    while i ≤ length(ss)
        for j in 1:i
            overlap1!(i,j, ss, o)
            j<i && overlap1!(j,i, ss, o)
        end
        i += 1
    end

    p = getirrsubsys(ss)
    ts = zero(rs)

    for rside in p
        push!(ts, rside=>rewrite_from_left(rside, ss))
    end
    return ts
end
