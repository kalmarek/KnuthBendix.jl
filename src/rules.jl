mutable struct Rule{W<:AbstractWord}
    lhs::W
    rhs::W
    id::UInt
    active::Bool
end

deactivate!(r::Rule) = r.active = false
isactive(r::Rule) = r.active
_hash!(r::Rule) = (r.id = hash(r.lhs, hash(r.rhs)); r)

function Words.store!(r::Rule, (lhs, rhs)::Pair)
    Words.store!(r.lhs, lhs)
    Words.store!(r, rhs)
    _hash!(r)
    return r
end

function Words.store!(r::Rule, word, side::Symbol)
    Words.store!(getfield(r, side), word)
    _hash!(r)
    return r
end

function Rule{W}(p::Pair) where {W}
    lhs, rhs = p
    rule = Rule{W}(lhs, rhs, UInt(0), true)
    _hash!(rule)
    return rule
end

function Rule{W}(l::AbstractWord, r::AbstractWord, o::Ordering) where {W}
    lhs, rhs = ifelse(lt(o, l, r), (r, l), (l, r))
    return Rule{W}(lhs => rhs)
end
Rule(l::W, r::W, o::Ordering) where {W} = Rule{W}(l, r, o)
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

"""
    rules(W::Type{<:AbstractWord}, o::Ordering)
Return the rules defined by `alphabet(o)`, consistent with order `o`.
"""
function rules(::Type{W}, o::Ordering) where {W<:AbstractWord}
    A = alphabet(o)
    res = Rule{W}[]

    for l in A
        hasinverse(l, A) || continue
        L = inv(l, A)
        x = W([A[l], A[L]])
        push!(res, Rule(x, one(x), o))
    end
    return res
end

"""
    simplify!(lhs::AbstractWord, rhs::AbstractWord, A::Alphabet)
Remove invertible (with respect to `A`) common prefixes and suffixes of `lhs` and `rhs`.
"""
function simplify!(lhs::AbstractWord, rhs::AbstractWord, A::Alphabet)
    common_suffix = 0
    k = min(length(lhs), length(rhs))
    @inbounds for i in 0:k-1
        l, r = lhs[end-i], rhs[end-i]
        l != r && break
        hasinverse(l, A) || break
        common_suffix += 1
    end

    if !iszero(common_suffix)
        resize!(lhs, length(lhs) - common_suffix)
        resize!(rhs, length(rhs) - common_suffix)
    end

    common_prefix = 0
    for (l, r) in zip(lhs, rhs)
        l != r && break
        hasinverse(l, A) || break
        common_prefix += 1
    end

    if !iszero(common_prefix)
        copyto!(lhs, 1, lhs, common_prefix + 1, length(lhs) - common_prefix)
        copyto!(rhs, 1, rhs, common_prefix + 1, length(rhs) - common_prefix)
        resize!(lhs, length(lhs) - common_prefix)
        resize!(rhs, length(rhs) - common_prefix)
    end

    return lhs, rhs
end

"""
    balancelength!(lhs::AbstractWord, rhs::AbstractWord, A::Alphabet)
Try to shorten `lhs` by moving letters from its sides to `rhs` (using inverses from `A`).
"""
function balancelength!(lhs::AbstractWord, rhs::AbstractWord, A::Alphabet)
    while length(lhs) > 2 && length(lhs) > length(rhs)
        hasinverse(last(lhs), A) || break
        push!(rhs, inv(pop!(lhs), A))
    end

    while length(lhs) > 2 && length(lhs) > length(rhs)
        hasinverse(first(lhs), A) || break
        pushfirst!(rhs, inv(popfirst!(lhs), A))
    end

    return lhs, rhs
end

function simplify!(
    lhs::AbstractWord,
    rhs::AbstractWord,
    o::Ordering;
    balance = false,
)
    lhs, rhs = simplify!(lhs, rhs, alphabet(o))
    if balance
        lhs, rhs = balancelength!(lhs, rhs, alphabet(o))
    end

    return lhs, rhs
end
