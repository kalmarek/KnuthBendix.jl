module FPMonoids
import GroupsCore as GC
import KnuthBendix as KB
import KnuthBendix: alphabet, Word

export FreeMonoid, FPMonoid, FPMonoidElement

# abstract methods

abstract type AbstractFPMonoid{I} <: GC.Monoid end

Base.one(M::AbstractFPMonoid{I}) where {I} = M(one(Word{I}), true)
GC.gens(M::AbstractFPMonoid{I}, i::Integer) where {I} = M(Word{I}(I[i]))
GC.gens(M::AbstractFPMonoid) = [GC.gens(M, i) for i in 1:length(alphabet(M))]
GC.ngens(M::AbstractFPMonoid) = length(alphabet(M))

# coercing to monoid
function (M::AbstractFPMonoid{I})(
    w::AbstractVector{<:Integer},
    reduced = false,
) where {I}
    res = FPMonoidElement(w, M, reduced)
    if length(w) > __wl_limit(M)
        normalform!(res)
    end
    return res
end

function Base.eltype(::Type{M}) where {M<:AbstractFPMonoid{I}} where {I}
    return FPMonoidElement{I,M}
end

__wl_limit(::AbstractFPMonoid) = 256

# types and constructors

const Relation{I} = NTuple{2,Word{I}}

struct FreeMonoid{I,A} <: AbstractFPMonoid{I}
    alphabet::A

    function FreeMonoid{I}(a::KB.Alphabet) where {I<:Integer}
        length(a) < typemax(I) ||
            throw("Too many letters in alphabet. Try with $(widen(I))")
        return new{I,typeof(a)}(a)
    end
end

FreeMonoid(a::KB.Alphabet) = FreeMonoid{UInt16}(a)
FreeMonoid(n::Integer) = FreeMonoid(KB.Alphabet([Symbol('a', i) for i in 1:n]))

struct FPMonoid{I,A,IA<:KB.IndexAutomaton} <: AbstractFPMonoid{I}
    alphabet::A
    relations::Vector{Relation{I}} # in case you need them later
    idx_automaton::IA
    confluent::Bool
end

# Accessors and basic manipulation
KB.alphabet(M::Union{<:FPMonoid,FreeMonoid}) = M.alphabet
rewriting(M::FreeMonoid) = alphabet(M)
rewriting(M::FPMonoid) = M.idx_automaton

Base.isfinite(M::FreeMonoid) = isempty(alphabet(M))
Base.isfinite(m::FPMonoid) = isfinite(m.idx_automaton) # finiteness of the language

mutable struct FPMonoidElement{I,M<:AbstractFPMonoid{I}} <: GC.MonoidElement
    word::Word{I}
    parent::M
    normalform::Bool

    function FPMonoidElement(
        w::AbstractVector,
        M::AbstractFPMonoid{I},
        reduced = false,
    ) where {I}
        return new{I,typeof(M)}(w, M, reduced)
    end
end

Base.parent(m::FPMonoidElement) = m.parent
word(m::FPMonoidElement) = m.word
isnormal(m::FPMonoidElement) = m.normalform

Base.one(m::FPMonoidElement) = one(parent(m))
Base.isone(m::FPMonoidElement) = (normalform!(m); isone(word(m)))
# this is technically a lie:
GC.isfiniteorder(x::FPMonoidElement) = isone(x)

# actual user-constructors for Monoid:

function FPMonoid(rws::KB.RewritingSystem)
    a = KB.alphabet(rws)
    if !KB.isreduced(rws)
        rws = KB.reduce!(rws)
    end
    rels = [Tuple(r) for r in rws.rules_orig]
    return FPMonoid(a, rels, KB.IndexAutomaton(rws), KB.isconfluent(rws))
end

function Base.:(/)(
    M::FreeMonoid{I},
    rels::AbstractArray{<:FPMonoidElement},
) where {I}
    return M / [(r, one(M)) for r in rels]
end

function Base.:(/)(
    M::FreeMonoid{I},
    rels::AbstractArray{<:Tuple{<:FPMonoidElement,<:FPMonoidElement}},
    ordering = KB.LenLex(alphabet(M));
    settings = KB.Settings(),
) where {I}
    A = M.alphabet
    new_rels = Relation{I}[word.(r) for r in rels]

    rws = KB.RewritingSystem(new_rels, ordering)
    R = KB.knuthbendix!(settings, rws)

    return FPMonoid(A, new_rels, KB.IndexAutomaton(R), KB.isconfluent(R))
end

function Base.show(io::IO, ::MIME"text/plain", M::FreeMonoid)
    return print(io, "free monoid over $(alphabet(M))")
end
function Base.show(io::IO, ::MIME"text/plain", M::FPMonoid)
    return print(
        io,
        "monoid defined by $(length(M.relations)) relations over $(alphabet(M))",
    )
end

function Base.:(*)(m::FPMonoidElement, ms::FPMonoidElement...)
    all(==(parent(m)), parent.(ms)) || throw(
        DomainError(
            (parent(m), parent.(ms)...),
            "cannot multiply elements from different monoids",
        ),
    )
    return parent(m)(*(word(m), word.(ms)...))
end

Base.:(^)(m::FPMonoidElement, n::Integer) = (parent(m))(word(m)^n)

"""
    normalform!(m::FPMonoidElement[, tmp::AbstractWord])
Reduce `m` to its normalform, as defined by the rewriting of `parent(m)`.
"""
function normalform!(m::FPMonoidElement)
    isnormal(m) && return m
    I = eltype(word(m))
    return normalform!(m, KB.Words.BufferWord{I}(I[]))
end
function normalform!(m::FPMonoidElement, buffer::KB.Words.BufferWord)
    w = word(m)
    KB.Words.store!(buffer, w)
    KB.rewrite!(w, buffer, rewriting(parent(m)))
    empty!(buffer)
    m.normalform = true
    return m
end

function Base.:(==)(m1::FPMonoidElement, m2::FPMonoidElement)
    parent(m1) === parent(m2) || return false
    normalform!(m1)
    normalform!(m2)
    return word(m1) == word(m2)
end

function Base.hash(m::FPMonoidElement, h::UInt)
    normalform!(m)
    return hash(word(m), hash(parent(m), h))
end

function Base.deepcopy_internal(m::FPMonoidElement, stackdict::IdDict)
    M = parent(m)
    return M(Base.deepcopy_internal(word(m), stackdict), isnormal(m))
end

function Base.show(io::IO, m::FPMonoidElement)
    m = normalform!(m)
    return KB.print_repr(io, word(m), alphabet(parent(m)))
end

Base.IteratorSize(::Type{<:FreeMonoid}) = Base.IsInfinite()

# eltype and IteratorSie implemented for AbstractMonoid
function Base.iterate(M::FPMonoid)
    idxA = rewriting(M)
    itr = KB.Automata.irreducible_words(idxA)
    w, st = iterate(itr)
    return M(w, true), (itr, st)
end

function Base.iterate(M::FPMonoid, state)
    itr, st = state
    k = iterate(itr, st)
    isnothing(k) && return nothing
    return M(first(k), true), (itr, last(k))
end

function GC.order(::Type{I}, M::FreeMonoid) where {I}
    isfinite(M) && return one(I)
    throw(GC.InfiniteOrder(M))
end

function GC.order(::Type{I}, M::FPMonoid) where {I}
    if isfinite(M)
        return convert(I, KB.Automata.num_irreducible_words(rewriting(M)))
    end

    verb = M.confluent ? "is" : "appears to be"
    msg = "monoid $verb infinite"
    if !M.confluent
        msg *= " (but the underlying rewriting system is not confluent)"
    end
    @error(msg)

    throw(GC.InfiniteOrder(M))
end

Base.length(M::AbstractFPMonoid) = GC.order(Int, M)

elements(M::FPMonoid, max_word_length) = elements(M, 0, max_word_length)

function elements(M::FPMonoid, min_word_lenght, max_word_length)
    words_itr = KB.Automata.irreducible_words(
        rewriting(M),
        min_word_lenght,
        max_word_length,
    )
    elts = [M(w, true) for w in words_itr]
    counts = zeros(Int, max_word_length + 1)
    for m in elts
        counts[length(word(m))+1] += 1
    end
    sizes = cumsum(counts)
    elts = sort!(elts, by = word, order = KB.LenLex(alphabet(M)))
    return elts, Dict(m => sizes[m+1] for m in min_word_lenght:max_word_length)
end

Base.adjoint(m::FPMonoidElement) = parent(m)(reverse(m.word))

end # of module Monoids

