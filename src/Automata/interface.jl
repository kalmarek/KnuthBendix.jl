"""
    Automaton{S} aka. DFA
Struct for deterministic finite automata (DFA) with states of type `S`.
"""
abstract type Automaton{S} end

"""
    initial(A::Automaton)
Return the initial state of a (deterministic) automaton.
"""
function initial(::Automaton) end

"""
	hasedge(A::Automaton, σ, label)
Check if `A` contains an edge starting at `σ` labeled by `label`
"""
function hasedge(at::Automaton{S}, σ::S, label) where {S} end

function addedge!(at::Automaton{S}, src::S, dst::S, label) where {S} end

"""
    isfail(A::Automaton, σ)
Check if state `σ` is a fail state in automaton `A`.
"""
function isfail(A::Automaton{S}, σ::S) where {S} end

"""
    isterminal(A::Automaton, σ)
Check if state `σ` is a terminal state of automaton `A`.
"""
function isterminal(A::Automaton{S}, σ::S) where {S} end

"""
	trace(label, A::Automaton, σ)
Return `τ` if `(σ, label, τ)` is in `A`, otherwise return nothing.
"""
function trace(label, A::Automaton{S}, σ::S) where {S} end

"""
	trace(w::AbstractVector, A::Automaton[, σ=initial(A)])
Return a pair `(l, τ)`, where
 * `l` is the length of the longest prefix of `w` which defines a path starting
 at `σ` in `A` and
 * `τ` is the last state (node) on the path.

Note: if `w` defines a path to a _fail state_ the last non-fail state will be
returned.
"""
@inline function trace(
    w::AbstractVector,
    A::Automaton{S},
    σ::S = initial(A),
) where {S}
    for (i, l) in enumerate(w)
        if hasedge(A, σ, l)
            τ = trace(l, A, σ)
        end
        if isfail(A, τ)
            return i - 1, σ
        end
        σ = τ
    end
    return length(w), σ
end
