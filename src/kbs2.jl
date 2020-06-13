"""
    test2!(rs::RewritingSystem, u::Word, v::Word, o::Ordering)
Adds a rule to a rewriting system (if necessary) that insures that there is
a word derivable form two given words using the rules in rewriting system.
See [Sims, p. 76].
"""
function test2!(rs::RewritingSystem{W}, stack::RewritingSystem{W}, o::Ordering = ordering(rs)) where W
    while !isempty(stack)
        lr, rr = pop!(stack)
        a = rewrite_from_left(lr, rs)
        b = rewrite_from_left(rr, rs)
        if a != b
            if lt(o, a, b)
                a, b = b, a
            end
            push!(rs, a => b)

            # lt(o, a, b) ? push!(rs, b => a) : push!(rs, a => b)
            for (i, (lhs, rhs)) in enumerate(rules(rs)[1:end-1])
                if active(rs)[i] && issubword(a, lhs)
                    setinactive!(rs, i)
                    push!(stack, lhs => rhs)
                else issubword(a, rhs)
                    rules(rs)[i] = (lhs => rewrite_from_left(rhs, rs))
                end
            end
        end
    end
end

"""
    overlap2!(rs::RewritingSystem, i::Integer, j::Integer, o::Ordering)
Checks the overlaps of right sides of rules at position i and j in the rewriting
system in which rule at i occurs at the beginning of the overlap. When failures
of local confluence are found, new rules are added. See [Sims, p. 77].
"""
function overlap2!(rs::RewritingSystem, stack::RewritingSystem, i::Integer, j::Integer, o::Ordering = ordering(rs))
    lhs_i, rhs_i = rules(rs)[i]
    lhs_j, rhs_j = rules(rs)[j]
    m = min(length(lhs_i), length(lhs_j)) - 1
    k = 1

    while k ≤ m && isactive(rs, i) && isactive(rs, j)
        b = @view lhs_i[end-k+1:end]
        if b == @view(lhs_j[1:k])
            a = lhs_i[1:end-k]; append!(a, rhs_j)
            c = lhs_j[k+1:end]; prepend!(c, rhs_i);
            push!(stack, a => c)
            test2!(rs, stack)
        end
        k += 1
    end
end

"""
    knuthbendix2(rs::RewritingSystem, o::Ordering)
Implements a Knuth-Bendix algorithm that yields reduced, confluent rewriting
system. See [Sims, p.77].

Warning: termination may not occur.
"""
function knuthbendix2!(rs::RewritingSystem{W, O}, o::Ordering = ordering(rs)) where {W, O}
    stack = empty(rs)
    tmprs = empty(rs)
    for (lhs, rhs) in rules(rs)
        push!(stack, lhs => rhs)
        test2!(tmprs, stack)
    end

    i = 1
    while i ≤ length(tmprs)
        j = 1
        while (j ≤ i && isactive(tmprs, i))
            if isactive(tmprs, j)
                overlap2!(tmprs, stack, i, j, o)
                j < i && isactive(tmprs, i) && isactive(tmprs, j) && overlap2!(tmprs, stack, j, i, o)
            end
            j += 1
        end
        i += 1
    end

    rs = empty!(rs)
    for rule in arules(tmprs)
        push!(rs, rule)
    end
    return rs
end

knuthbendix2(rws::RewritingSystem) = knuthbendix2!(deepcopy(rws))
