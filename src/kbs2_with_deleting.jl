"""
    mutable struct kbWork
Helper structure used to iterate over rewriting system in Knuth-Bendix procedure.
`i` field is the iterator over the outer loop and `j` is the iterator over the
inner loop. `_vWord` and `_wWord` are inner `BufferWord`s used for rewriting.
"""
mutable struct kbWork
    i::Int
    j::Int
    _vWord::BufferWord{UInt16}
    _wWord::BufferWord{UInt16}
end

kbWork(i::Int, j::Int) = kbWork(i, j, BufferWord(), BufferWord())

get_i(wrk::kbWork) = wrk.i
get_j(wrk::kbWork) = wrk.j
get_v_word(wrk::kbWork) = wrk._vWord
get_w_word(wrk::kbWork) = wrk._wWord


"""
    deriverule!(rs::RewritingSystem, stack, work::kbWork
        [, o::Ordering=ordering(rs), deleteinactive::Bool = false])
Adds a rule to a rewriting system and deactivates others (if necessary) that
insures that the set of rules is reduced while maintining local confluence.
See [Sims, p. 76].
"""
function deriverule!(rs::RewritingSystem, stack, work::kbWork,
    o::Ordering = ordering(rs), deleteinactive::Bool = false)
    if length(stack) >= 2
        @debug "Deriving rules with stack of length=$(length(stack))"
    end
    while !isempty(stack)
        lr, rr = pop!(stack)
        a = rewrite_from_left(lr, work, rs)
        b = rewrite_from_left(rr, work, rs)
        if a != b
            simplifyrule!(a, b, alphabet(o))
            lt(o, a, b) ? rule = b => a : rule = a => b
            push!(rs, rule)

            for i in 1:length(rules(rs))-1
                isactive(rs, i) || continue
                (lhs, rhs) = rules(rs)[i]
                if occursin(rule.first, lhs)
                    setinactive!(rs, i)
                    push!(stack, lhs => rhs)
                    deleteinactive && push!(rs._inactiverules, i)
                elseif occursin(rule.first, rhs)
                    new_rhs = rewrite_from_left(rhs, work, rule)
                    rules(rs)[i] = (lhs => rewrite_from_left(new_rhs, work, rs))
                end
            end
        end
    end
end

"""
    knuthbendix2delinactive!(rws::RewritingSystem[, o::Ordering=ordering(rws);
        maxrules::Integer=100])
Implements the Knuth-Bendix completion algorithm that yields a reduced,
confluent rewriting system. See [Sims, p.77].

Warning: forced termiantion takes place after the number of rules stored within
the RewritngSystem reaches `maxrules`.
"""
function knuthbendix2delinactive!(rws::RewritingSystem,
    o::Ordering = ordering(rws); maxrules::Integer = 100)
    stack = copy(rules(rws)[active(rws)])
    rws = empty!(rws)
    deriverule!(rws, stack, nothing, o, true)
    work = kbWork(1, 0)

    while get_i(work) ≤ length(rules(rws))
        # @debug "number_of_active_rules" sum(active(rws))
        if sum(active(rws)) > maxrules
            @warn("Maximum number of rules ($maxrules) in the RewritingSystem reached.
                You may retry with `maxrules` kwarg set to higher value.")
            break
        end
        work.j = 1
        while (get_j(work) ≤ get_i(work))
            forceconfluence!(rws, stack, get_i(work), get_j(work), o, true, work)
            if get_j(work) < get_i(work) && isactive(rws, get_i(work)) && isactive(rws, get_j(work))
                forceconfluence!(rws, stack, get_j(work), get_i(work), o, true, work)
            end
            removeinactive!(rws, work)
            work.j += 1
        end
        work.i += 1
    end
    return rws
end

function knuthbendix2delinactive(rws::RewritingSystem; maxrules::Integer = 100)
    knuthbendix2delinactive!(deepcopy(rws), maxrules=maxrules)
end

"""
    function removeinactive!(rws::RewritingSystem, work::kbWork)
Function removing inactive rules from the given `RewritingSystem` and updating
indices used to iterate in Knuth-Bendix procedure and stored in `kbWork`.
"""
function removeinactive!(rws::RewritingSystem, work::kbWork)
    hasinactiverules(rws) || return
    isempty(rws) && return
    sort!(rws._inactiverules)

    while !isempty(rws._inactiverules)
        idx = pop!(rws._inactiverules)
        deleteat!(rws, idx)
        idx ≤ get_i(work) && (work.i -= 1)
        idx ≤ get_j(work) && (work.j -= 1)
    end
end

"""
    function rewrite_from_left(u::W, wrk::kbWork, rewriting)
Rewrites a word from left using internal buffer words from `kbWork` object and
`rewriting` object. The `rewriting` object must implement
`rewrite_from_left!(v::AbstractWord, w::AbstractWord, rewriting)` to succesfully
rewrite `u`.
"""
function rewrite_from_left(u::W, wrk::kbWork, rewriting) where {W<:AbstractWord}
    isempty(rewriting) && return u
    empty!(wrk._vWord)
    resize!(wrk._wWord, length(u))
    copyto!(wrk._wWord, u)
    rewrite_from_left!(wrk._vWord, wrk._wWord, rewriting)
    return W(wrk._vWord)
end
