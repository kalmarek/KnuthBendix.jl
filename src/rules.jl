mutable struct Rule{W<:AbstractWord}
    lhs::W
    rhs::W
    id::UInt
    active::Bool
end
Rule{W}(lhs::AbstractWord, rhs::AbstractWord) where W =
    Rule{W}(lhs, rhs, hash(lhs, hash(rhs)), true)
Rule(lhs::W, rhs::W) where W<:AbstractWord = Rule{W}(lhs, rhs)
Rule(rule::Pair{W}) where W = Rule(first(rule), last(rule))

function Base.:(==)(rule1::Rule{W}, rule2::Rule{W}) where W
    rule1.id == rule2.id || return false
    res = (rule1.lhs == rule2.lhs) && (rule1.rhs == rule2.rhs)
    res || @warn "hash collision between"
    return res
end

deactivate!(r::Rule) = r.active = false

isactive(r::Rule) = r.active

Base.iterate(r::Rule) = r.lhs, 1
Base.iterate(r::Rule, ::Any) = r.rhs, nothing
Base.iterate(r::Rule, ::Nothing) = nothing
Base.length(r::Rule) = 2
Base.eltype(r::Rule{W}) where W = W

Base.show(io::IO, r::Rule) = ((a,b) = r; print(io, a, " ⇒ ", b))
