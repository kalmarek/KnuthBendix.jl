"""
    test1!(rs::RewritingSystem, u::Word, v::Word, o::Ordering)
Adds a rule to a rewriting system (if necessary) that insures that there is
a word derivable form two given words using the rules in rewriting system.
See [Sims, p. 69].
"""
function test1!(rs::RewritingSystem{W,O}, u::W, v::W, o::Ordering = ordering(rs))  where {W<:AbstractWord, O<:Ordering}
    a = rewrite_from_left(u, rs)
    b = rewrite_from_left(v, rs)
    if a != b
        lt(o, a, b) ? push!(rs, b=>a) : push!(rs, a=>b)
    end
end

"""
    overlap1!(rs::RewritingSystem, i::Integer, j::Integer, o::Ordering)
Checks the overlaps of right sides of rules at position i and j in the rewriting
system in which rule at i occurs at the beginning of the overlap. When failures
of local confluence are found, new rules are added. See [Sims, p. 69].
"""
function overlap1!(rs::RewritingSystem{W,O},i::Integer, j::Integer,  o::Ordering = ordering(rs)) where {W<:AbstractWord, O<:Ordering}
    lhs_i, rhs_i = rules(rs)[i]
    lhs_j, rhs_j = rules(rs)[j]
    for k in 1:length(lhs_i)
        a = W(lhs_i[1:end-k])
        b = W(lhs_i[end-k+1:end])
        n = longestcommonprefix(b, lhs_j)
        if isone(W(b[n+1:end])) || isone(W(lhs_j[n+1:end]))
            test1!(rs, a * rhs_j * W(b[n+1:end]), rhs_i * W(lhs_j[n+1:end]), o)
        end
    end
end

"""
    getirrsubsys(rs::RewritingSystem)
Returns a list of right sides of rules from rewriting system of which all the
proper subwords are irreducible with respect to this rewriting system.
"""
function getirrsubsys(rs::RewritingSystem{W,O})  where {W<:AbstractWord, O<:Ordering}
    rsides = []
    for (lhs, rhs) in rules(rs)
        ok = true
        n = length(lhs)
        if n > 2
            for j in 2:(n-1)
                w = W(lhs[1:j])
                rw = rewrite_from_left(w, rs)
                (w == rw) || (ok=false; break)
            end
            for i in 2:(n-1)
                ok || break
                for j in (i+1):n
                    w = W(lhs[i:j])
                    rw = rewrite_from_left(w, rs)
                    (w == rw) || (ok=false; break)
                end
            end
        end
        ok && push!(rsides, lhs)
    end
    return rsides
end

"""
    knuthbendix1(rs::RewritingSystem, o::Ordering)
Implements a Knuth-Bendix algorithm that yields reduced, confluent rewriting
system. See [Sims, p.68].

Warning: termination may not occur.
"""
function knuthbendix1(rs::RewritingSystem, o::Ordering = ordering(rs))
    i = 1
    ss = zero(rs)

    for (rhs, lhs) in rules(rs)
        test1!(ss, lhs, rhs, o)
    end
    while i ≤ length(ss)
        for j in 1:i
            overlap1!(ss, i,j, o)
            j<i && overlap1!(ss, j,i, o)
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
