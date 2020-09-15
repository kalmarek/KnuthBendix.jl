"""
    deriverule!(rws::RewritingSystem, u::Word, v::Word[, o::Ordering=ordering(rws)])
Adds a rule to a rewriting system (if necessary) that insures that there is
a word derivable form two given words using the rules in rewriting system.
See [Sims, p. 69].
"""
function deriverule!(rws::RewritingSystem{W}, u::W, v::W,
    o::Ordering = ordering(rws)) where W

    a = rewrite_from_left(u, rws)
    b = rewrite_from_left(v, rws)
    if a != b
        lt(o, a, b) ? push!(rws, b => a) : push!(rws, a => b)
    end
    return rws
end

"""
    forceconfluence!(rws::RewritingSystem, i::Integer, j::Integer
    [, o::Ordering=ordering(rws)])
Checks the overlaps of right sides of rules at position i and j in the rewriting
system in which rule at i occurs at the beginning of the overlap. When failures
of local confluence are found, new rules are added. See [Sims, p. 69].
"""
function forceconfluence!(rws::RewritingSystem, i::Integer, j::Integer,
    o::Ordering = ordering(rws))

    lhs_i, rhs_i = rules(rws)[i]
    lhs_j, rhs_j = rules(rws)[j]
    for k in 1:length(lhs_i)
        b = @view lhs_i[end-k+1:end]
        n = longestcommonprefix(b, lhs_j)
        if isone(@view b[n+1:end]) || isone(@view lhs_j[n+1:end])
            a = lhs_i[1:end-k]; append!(a, rhs_j); append!(a, @view b[n+1:end]);

            deriverule!(rws, a, rhs_i * @view(lhs_j[n+1:end]), o)
        end
    end
    return rws
end

"""
    isirreducible(w::AbstractWord, rws::RewritingSystem)
Returns whether a word is irreducible with respect to a given rewriting system
"""
function isirreducible(w::AbstractWord, rws::RewritingSystem)
    for (lhs, _) in rules(rws)
        occursin(lhs, w) && return false
    end
    return true
end

"""
    getirrsubsys(rws::RewritingSystem)
Returns a list of right sides of rules from rewriting system of which all the
proper subwords are irreducible with respect to this rewriting system.
"""
function getirrsubsys(rws::RewritingSystem{W}) where W
    rsides = W[]
    for (lhs, _) in rules(rws)
        ok = true
        n = length(lhs)
        if n > 2
            for j in 2:(n-1)
                w = @view(lhs[1:j])
                isirreducible(w, rws) || (ok = false; break)
            end
            for i in 2:(n-1)
                ok || break
                for j in (i+1):n
                    w = @view(lhs[i:j])
                    isirreducible(w, rws) || (ok = false; break)
                end
            end
        end
        ok && push!(rsides, lhs)
    end
    return rsides
end

"""
    knuthbendix1(rws::RewritingSystem[, o::Ordering=ordering(rs); maxrules=100])
Implements a Knuth-Bendix algorithm that yields reduced, confluent rewriting
system. See [Sims, p.68].

Warning: termination may not occur.
"""
function knuthbendix1!(rws::RewritingSystem, o::Ordering = ordering(rws); maxrules::Integer = 100)
    ss = empty(rws)
    for (lhs, rhs) in rules(rws)
        deriverule!(ss, lhs, rhs, o)
    end

    i = 1
    while i ≤ length(ss)
        @debug "at iteration $i rws contains $(length(ss.rwrules)) rules"
        if length(ss) >= maxrules
            @warn("Maximum number of rules ($maxrules) in the RewritingSystem reached.
                You may retry with `maxrules` kwarg set to higher value.")
            break
        end
        for j in 1:i
            forceconfluence!(ss, i, j, o)
            j < i && forceconfluence!(ss, j, i, o)
        end
        i += 1
    end

    p = getirrsubsys(ss)
    rs = empty!(rws)

    for rside in p
        push!(rws, rside => rewrite_from_left(rside, ss))
    end
    return rws
end

function knuthbendix1(rws::RewritingSystem; maxrules::Integer = 100)
    knuthbendix1!(deepcopy(rws), maxrules=maxrules)
end
