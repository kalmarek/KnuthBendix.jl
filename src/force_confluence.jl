##################################
# Crude, i.e., KBS1 implementation
##################################

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

##########################
# Naive KBS implementation
##########################

"""
    forceconfluence!(rs::RewritingSystem, stack, i::Integer, j::Integer
    [, o::Ordering=ordering(rs)])
Checks the proper overlaps of right sides of active rules at position i and j
in the rewriting system. When failures of local confluence are found, new rules
are added. See [Sims, p. 77].
"""
function forceconfluence!(rs::RewritingSystem, stack, i::Integer, j::Integer,
    o::Ordering = ordering(rs))
    lhs_i, rhs_i = rules(rs)[i]
    lhs_j, rhs_j = rules(rs)[j]
    m = min(length(lhs_i), length(lhs_j)) - 1
    k = 1

    while k ≤ m && isactive(rs, i) && isactive(rs, j)
        if issuffix(lhs_j, lhs_i, k)
            a = lhs_i[1:end-k]; append!(a, rhs_j)
            c = lhs_j[k+1:end]; prepend!(c, rhs_i);
            push!(stack, a => c)
            deriverule!(rs, stack, o)
        end
        k += 1
    end
end


#####################################
# KBS with deletion of inactive rules
#####################################

# As of now: default implementation

"""
    forceconfluence!(rs::RewritingSystem, stack, work:kbWork, i::Integer, j::Integer
    [, o::Ordering=ordering(rs)])
Checks the proper overlaps of right sides of active rules at position i and j
in the rewriting system. When failures of local confluence are found, new rules
are added. See [Sims, p. 77].
"""
function forceconfluence!(rs::RewritingSystem, stack, work::kbWork, i::Integer, j::Integer,
    o::Ordering = ordering(rs))
    lhs_i, rhs_i = rules(rs)[i]
    lhs_j, rhs_j = rules(rs)[j]
    m = min(length(lhs_i), length(lhs_j)) - 1
    k = 1

    while k ≤ m && isactive(rs, i) && isactive(rs, j)
        if issuffix(lhs_j, lhs_i, k)
            a = lhs_i[1:end-k]; append!(a, rhs_j)
            c = lhs_j[k+1:end]; prepend!(c, rhs_i);
            push!(stack, a => c)
            deriverule!(rs, stack, work, o)
        end
        k += 1
    end
end

########################################
# KBS using index automata for rewriting
########################################

"""
    forceconfluence!(rs::RewritingSystem, stack, work::kbWork, at::Automaton,
        i::Integer, j::Integer [, o::Ordering=ordering(rs)],)
Checks the proper overlaps of right sides of active rules at position i and j
in the rewriting system. When failures of local confluence are found, new rules
are added. See [Sims, p. 77].
"""
function forceconfluence!(rs::RewritingSystem, stack, work::kbWork, at::Automaton,
    i::Integer, j::Integer, o::Ordering = ordering(rs))
    lhs_i, rhs_i = rules(rs)[i]
    lhs_j, rhs_j = rules(rs)[j]
    m = min(length(lhs_i), length(lhs_j)) - 1
    k = 1

    while k ≤ m && isactive(rs, i) && isactive(rs, j)
        if issuffix(lhs_j, lhs_i, k)
            a = lhs_i[1:end-k]; append!(a, rhs_j)
            c = lhs_j[k+1:end]; prepend!(c, rhs_i);
            push!(stack, a => c)
            deriverule!(rs, stack, work, at, o)
        end
        k += 1
    end
end
