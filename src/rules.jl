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
    Words.store!(r, lhs, :lhs)
    Words.store!(r, rhs, :rhs)
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

word_type(::Type{<:Rule{W}}) where {W} = W

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
    simplify!(u::AbstractWord, w::AbstractWord, A::Alphabet)
Remove (invertible w.r.t. `A`) common prefixes and suffixes of `u` and `w`.
"""
function simplify!(u::AbstractWord, w::AbstractWord, A::Alphabet)
    common_suffix = 0
    k = min(length(u), length(w))
    @inbounds for i in 0:k-1
        l, r = u[end-i], w[end-i]
        l != r && break
        hasinverse(l, A) || break
        common_suffix += 1
    end

    if !iszero(common_suffix)
        resize!(u, length(u) - common_suffix)
        resize!(w, length(w) - common_suffix)
    end

    common_prefix = 0
    for (l, r) in zip(u, w)
        l != r && break
        hasinverse(l, A) || break
        common_prefix += 1
    end

    if !iszero(common_prefix)
        copyto!(u, 1, u, common_prefix + 1, length(u) - common_prefix)
        copyto!(w, 1, w, common_prefix + 1, length(w) - common_prefix)
        resize!(u, length(u) - common_prefix)
        resize!(w, length(w) - common_prefix)
    end

    return u, w
end

"""
    balancelength!(u::AbstractWord, w::AbstractWord, A::Alphabet)
Balance the lengths of `u` and `w` by using inverses from `A`.
"""
function balancelength!(u::AbstractWord, w::AbstractWord, A::Alphabet)
    (u, w) = length(u) > length(w) ? (u, w) : (w, u)
    while length(u) > 2 && length(u) > length(w)
        hasinverse(last(u), A) || break
        push!(w, inv(pop!(u), A))
    end

    while length(u) > 2 && length(u) > length(w)
        hasinverse(first(u), A) || break
        pushfirst!(w, inv(popfirst!(u), A))
    end

    return u, w
end

"""
    simplify!(u::AbstractWord, w::AbstractWord, o::Ordering[; balance=false])
Simplify the candidates `u` and `w` for optimal rule creation.

This removes invertible (with respect to `alphabet(o)`) common prefixes and
suffixes as well as balances the lenghts of `u` and `w`.

The words returned `(lhs, rhs)` are possibly aliased with `u` and `w` and
satisfy `lhs > rhs` w.r.t. ordering `o`.
"""
function simplify!(
    u::AbstractWord,
    w::AbstractWord,
    o::Ordering;
    balance = false,
)
    u, w = simplify!(u, w, alphabet(o))
    if balance
        u, w = balancelength!(u, w, alphabet(o))
    end
    return ifelse(lt(o, u, w), (w, u), (u, w))
end
