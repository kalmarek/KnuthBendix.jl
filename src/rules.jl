mutable struct Rule{W<:AbstractWord}
    lhs::W
    rhs::W
    id::UInt
    active::Bool
end

deactivate!(r::Rule) = r.active = false
isactive(r::Rule) = r.active

function update_rhs!(r::Rule, new_rhs)
    store!(r.rhs, new_rhs)
    r.id = hash(r.lhs, hash(r.rhs))
    return r
end

function Rule{W}(l::AbstractWord, r::AbstractWord, o::Ordering) where {W}
    lhs, rhs = lt(o, l, r) ? (r, l) : (l, r)
    @assert !lt(o, lhs, rhs) "$lhs should be larger than $rhs"
    return Rule{W}(lhs, rhs, hash(lhs, hash(rhs)), true)
end
Rule(l::W, r::W, o::Ordering) where {W} = Rule{W}(l, r, o)

function Rule{W}(p::Pair) where {W}
    lhs, rhs = p
    return Rule{W}(lhs, rhs, hash(lhs, hash(rhs)), true)
end

Rule(p::Pair{W,W}) where {W} = Rule{W}(p)

function Base.:(==)(rule1::Rule{W}, rule2::Rule{W}) where {W}
    rule1.id == rule2.id || return false
    res = (rule1.lhs == rule2.lhs) && (rule1.rhs == rule2.rhs)
    res || @warn "hash collision between $rule1 and $rule2"
    return res
end
Base.hash(r::Rule, h::UInt) = hash(r.id, h)

Base.iterate(r::Rule) = r.lhs, 1
Base.iterate(r::Rule, ::Any) = r.rhs, nothing
Base.iterate(r::Rule, ::Nothing) = nothing
Base.length(r::Rule) = 2
Base.last(r::Rule) = first(iterate(r, 1))
Base.eltype(::Type{Rule{W}}) where {W} = W

Base.show(io::IO, r::Rule) = ((a, b) = r; print(io, a, " ⇒ ", b))

function rules(::Type{W}, o::WordOrdering) where {W<:AbstractWord}
    A = alphabet(o)
    res = Rule{W}[]

    for l in letters(A)
        hasinverse(l, A) || continue
        L = inv(A, l)
        x = W([A[l], A[L]])
        push!(res, Rule(x, one(x), o))
    end
    return res
end

mutable struct RulesIter{R,S}
    rules::R
    inner_state::S
end

Base.eltype(::Type{RulesIter{R}}) where {R} = eltype(R)
Base.IteratorSize(::Type{<:RulesIter}) = Base.SizeUnknown()

function Base.iterate(itr::RulesIter, state...)
    y = Base.iterate(itr.rules, itr.inner_state)
    while !isnothing(y)
        itr.inner_state = last(y)
        isactive(first(y)) && return y
        y = Base.iterate(itr.rules, itr.inner_state)
    end
    return nothing
end

function remove_inactive!(rws, RI, RJ)
    i = 0
    j = 0
    for (idx, r) in enumerate(rws.rwrules)
        if !isactive(r)
            if idx ≤ RI.inner_state
                i += 1
            end
            if idx ≤ RI.inner_state
                j += 1
            end
        end
        idx ≥ max(RI.inner_state, RJ.inner_state) && break
    end
    RI.inner_state -= i
    RJ.inner_state -= j
    remove_inactive!(rws)
    return rws
end

function remove_inactive!(rws, RI)
    i = 0
    for (idx, r) in enumerate(rws.rwrules)
        if !isactive(r)
            if idx ≤ RI.inner_state
                i += 1
            end
        end
        idx ≥ RI.inner_state && break
    end
    RI.inner_state -= i
    remove_inactive!(rws)
    return rws
end

remove_inactive!(rws) = (filter!(isactive, rws.rwrules); rws)
