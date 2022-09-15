"""
    rewrite_from_left(u::AbstractWord, rewriting)
Rewrites word `u` (from left) using `rewriting` object. The object must implement
`rewrite_from_left!(v::AbstractWord, w::AbstractWord, rewriting)`.
"""
@inline function rewrite_from_left(
    u::W,
    rewriting,
    vbuff = Words.BufferWord{T}(0, length(u)),
    wbuff = Words.BufferWord{T}(length(u), 0),
) where {T,W<:AbstractWord{T}}
    isempty(rewriting) && return u
    Words.store!(wbuff, u)
    v = rewrite_from_left!(vbuff, wbuff, rewriting)
    return W(v, false)
end

function rewrite_from_left!(v::AbstractWord, w::AbstractWord, A::Any)
    msg_ = [
        "No method for rewriting with $(typeof(A)).",
        "You need to implement",
        "KnuthBendix.rewrite_from_left!(::AbstractWord, ::AbstractWord, ::$(typeof(A)))",
        "yourself",
    ]
    throw(join(msg_, " "))
end
"""
    rewrite_from_left!(v::AbstractWord, w::AbstractWord, rule::Rule)
Rewrite word `w` storing the result in `v` by using a single rewriting `rule`.
"""
@inline function rewrite_from_left!(v::AbstractWord, w::AbstractWord, rule::Rule)
    v = resize!(v, 0)
    lhs, rhs = rule
    while !isone(w)
        push!(v, popfirst!(w))
        if issuffix(lhs, v)
            prepend!(w, rhs)
            resize!(v, length(v) - length(lhs))
        end
    end
    return v
end

"""
    rewrite_from_left!(v::AbstractWord, w::AbstractWord, A::Alphabet)
Rewrite word `w` storing the result in `v` by applying free reductions as
defined by the inverses present in alphabet `A`.
"""
@inline function rewrite_from_left!(v::AbstractWord, w::AbstractWord, A::Alphabet)
    v = resize!(v, 0)
    while !isone(w)
        if isone(v)
            push!(v, popfirst!(w))
        else
            # the first check is for monoids only
            if hasinverse(last(v), A) && inv(A, last(v)) == first(w)
                pop!(v)
                popfirst!(w)
            else
                push!(v, popfirst!(w))
            end
        end
    end
    return v
end

