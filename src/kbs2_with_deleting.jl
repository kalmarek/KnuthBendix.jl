abstract type AbstractBufferPair{T} end

"""
    struct BufferPair{T}  <: AbstractBufferPair{T}
A helper struct used to store pair of `BufferWord` used for rewriting.
`BufferPair`s are used in conjucntion with `kbWork` struct.
"""
struct BufferPair{T} <: AbstractBufferPair{T}
    _vWord::BufferWord{T}
    _wWord::BufferWord{T}
end

BufferPair{T}() where {T} = BufferPair(one(BufferWord{T}), one(BufferWord{T}))

get_v_word(bp::BufferPair) = wrk._vWord
get_w_word(bp::BufferPair) = wrk._wWord

"""
    mutable struct kbWork{T}
Helper structure used to iterate over rewriting system in Knuth-Bendix procedure.
`i` field is the iterator over the outer loop and `j` is the iterator over the
inner loop. `lhsPair` and `rhsPair` are inner `BufferPair`s used for rewriting.
`_inactiverules` is just a list of inactive rules in the `RewritingSystem`
subjected to Knuth-Bendix procedure.
"""
mutable struct kbWork{T}
    i::Int
    j::Int
    lhsPair::BufferPair{T}
    rhsPair::BufferPair{T}
    _inactiverules::Vector{Int}
end

kbWork{T}(i::Int, j::Int) where {T} = kbWork(i, j, BufferPair{T}(), BufferPair{T}(), Int[])

get_i(wrk::kbWork) = wrk.i
get_j(wrk::kbWork) = wrk.j
inactiverules(wrk::kbWork) = wrk._inactiverules
hasinactiverules(wrk::kbWork) = !isempty(wrk._inactiverules)


"""
    deriverule!(rs::RewritingSystem, stack, work::kbWork
        [, o::Ordering=ordering(rs), deleteinactive::Bool = false])
Adds a rule to a rewriting system and deactivates others (if necessary) that
insures that the set of rules is reduced while maintining local confluence.
See [Sims, p. 76].
"""
function deriverule!(rs::RewritingSystem{W}, stack, work::kbWork,
    o::Ordering = ordering(rs), deleteinactive::Bool = false) where {W<:AbstractWord}
    if length(stack) >= 2
        @debug "Deriving rules with stack of length=$(length(stack))"
    end
    while !isempty(stack)
        lr, rr = pop!(stack)
        a = rewrite_from_left(lr, work.lhsPair, rs)
        b = rewrite_from_left(rr, work.rhsPair, rs)
        if a != b
            simplifyrule!(a, b, alphabet(o))
            lt(o, a, b) ? rule = W(b) => W(a) : rule = W(a) => W(b)
            push!(rs, rule)

            for i in 1:length(rules(rs))-1
                isactive(rs, i) || continue
                (lhs, rhs) = rules(rs)[i]
                if occursin(rule.first, lhs)
                    setinactive!(rs, i)
                    push!(stack, lhs => rhs)
                    deleteinactive && push!(work._inactiverules, i)
                elseif occursin(rule.first, rhs)
                    rules(rs)[i] = (lhs => W(rewrite_from_left(rhs, work.rhsPair, rs)))
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
function knuthbendix2delinactive!(rws::RewritingSystem{W},
    o::Ordering = ordering(rws); maxrules::Integer = 100) where {W<:AbstractWord}
    stack = copy(rules(rws)[active(rws)])
    rws = empty!(rws)
    T = eltype(W)
    work = kbWork{T}(1, 0)
    deriverule!(rws, stack, work, o, true)

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
    hasinactiverules(work) || return
    isempty(rws) && return
    sort!(work._inactiverules)

    while !isempty(work._inactiverules)
        idx = pop!(work._inactiverules)
        deleteat!(rws, idx)
        idx ≤ get_i(work) && (work.i -= 1)
        idx ≤ get_j(work) && (work.j -= 1)
    end
end

"""
    function rewrite_from_left(u::W, bp::BufferPair, rewriting)
Rewrites a word from left using buffer words from `BufferPair` declared in `kbWork`
object and `rewriting` object. The `rewriting` object must implement
`rewrite_from_left!(v::AbstractWord, w::AbstractWord, rewriting)` to succesfully
rewrite `u`.
Important: this implementation returns an instance of `BufferWord`!
"""
function rewrite_from_left(u::W, bp::BufferPair, rewriting) where {W<:AbstractWord}
    isempty(rewriting) && (resize!(bp._vWord, length(u)); copyto!(bp._vWord, u); return bp._vWord)
    empty!(bp._vWord)
    resize!(bp._wWord, length(u))
    copyto!(bp._wWord, u)
    v = rewrite_from_left!(bp._vWord, bp._wWord, rewriting)
    return v
end
