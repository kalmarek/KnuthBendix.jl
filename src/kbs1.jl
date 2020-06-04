"""
    test1!(rs::RewritingSystem, u::Word, v::Word, o::Ordering)
Adds a rule to a rewriting system (if necessary) that insures that there is
a word derivable form two given words using the rules in rewriting system.
See [Sims, p. 69].
"""
function test1!(rs::RewritingSystem{W}, u::W, v::W, o::Ordering = ordering(rs)) where W
    a = rewrite_from_left(u, rs)
    b = rewrite_from_left(v, rs)
    if a != b
        lt(o, a, b) ? push!(rs, b => a) : push!(rs, a => b)
    end
    return rs
end

"""
    overlap1!(rs::RewritingSystem, i::Integer, j::Integer, o::Ordering)
Checks the overlaps of right sides of rules at position i and j in the rewriting
system in which rule at i occurs at the beginning of the overlap. When failures
of local confluence are found, new rules are added. See [Sims, p. 69].
"""
function overlap1!(rs::RewritingSystem, i::Integer, j::Integer, o::Ordering = ordering(rs))
    lhs_i, rhs_i = rules(rs)[i]
    lhs_j, rhs_j = rules(rs)[j]
    for k in 1:length(lhs_i)
        b = @view lhs_i[end-k+1:end]
        n = longestcommonprefix(b, lhs_j)
        if isone(@view b[n+1:end]) || isone(@view lhs_j[n+1:end])
            # a = lhs_i[1:end-k] * rhs_j * b[n+1:end]
            a = lhs_i[1:end-k]; append!(a, rhs_j); append!(a, @view b[n+1:end]);

            test1!(rs, a, rhs_i * @view(lhs_j[n+1:end]), o)
        end
    end
    return rs
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
                w = lhs[1:j]
                rw = rewrite_from_left(w, rs)
                (w == rw) || (ok=false; break)
            end
            for i in 2:(n-1)
                ok || break
                for j in (i+1):n
                    w = lhs[i:j]
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

    ss = empty(rs)
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
    ts = empty(rs)

    for rside in p
        push!(ts, rside=>rewrite_from_left(rside, ss))
    end
    return ts
end
