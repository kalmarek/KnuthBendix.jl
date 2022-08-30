## States

mutable struct State{I,D,V}
    transitions::Vector{State{I,D,V}}
    uptodate::Bool
    id::I
    data::D
    value::V

    State{I,D,V}() where {I,D,V} = new{I,D,V}()
    function State{I,D,V}(transitions::AbstractVector, id) where {I,D,V}
        return new{I,D,V}(transitions, true, id)
    end
end

function State{I,D,V}(id, data; max_degree::Integer) where {I,D,V}
    S = State{I,D,V}
    st = S(Vector{S}(undef, max_degree), id)
    st.data = data
    return st
end

isfail(s::State) = !isdefined(s, :transitions)
isterminal(s::State) = isdefined(s, :value)
id(s::State) = s.id

function hasedge(s::State, i::Integer)
    return isassigned(s.transitions, i) && !isfail(s.transitions[i])
end

function Base.getindex(s::State, i::Integer)
    !hasedge(s, i) && return nothing
    return s.transitions[i]
end
function Base.setindex!(s::State, v::State, i::Integer)
    return s.transitions[i] = v
end

function value(s::State)
    isterminal(s) && return s.value
    return throw("state is not terminal and its value is not assigned")
end
setvalue!(s::State, v) = s.value = v

max_degree(s::State) = length(s.transitions)
degree(s::State) = count(i -> hasedge(s, i), 1:max_degree(s))
iscomplete(s::State) = degree(s) == max_degree(s)

transitions(s::State) = (s[i] for i in 1:max_degree(s) if hasedge(s, i))

function Base.show(io::IO, s::State)
    if isfail(s)
        print(io, "fail")
    elseif isterminal(s)
        print(io, "TState: ", value(s))
    else
        print(io, "NTState: ", id(s), " (data=", s.data, ")")
    end
end

function Base.show(io::IO, ::MIME"text/plain", s::State)
    if isfail(s)
        print(io, "fail state")
    elseif isterminal(s)
        println(io, "Terminal state")
        println(io, "\tvalue: $(value(s))")
    else
        println(io, "Non-terminal state: ", id(s))
        println(io, "\tdata: ", s.data)
        println(io, "\ttransitions:")
        for l in 1:max_degree(s)
            !hasedge(s, l) && continue
            print(io, "\t\t$l → ")
            show(io, s[l])
            println(io)
        end
    end
end

###########################################
# Automata

abstract type Automaton end

"""
	hasedge(A::Automaton, σ, label)
Check if `A` contains an edge starting at `σ` labeled by `label`
"""
function hasedge(A::Automaton, σ, label) end

function addedge!(A::Automaton, src::S, dst::S, label) where {S} end

"""
	trace(label, A::Automaton, σ)
Return `τ` if `(σ, label, τ)` is in `A`, otherwise return nothing.
"""
function trace(label, A::Automaton, σ) end

"""
	trace(w::AbstractVector{<:Integer}, A::Automaton[, σ=initial(A)])
Return a pair `(l, τ)`, where
 * `l` is the length of the longest prefix of `w` which defines a path starting at `σ` in `A` and
 * `τ` is the last state (node) on the path.
"""
@inline function trace(w::AbstractVector, A::Automaton, σ = initial(A))
    for (i, l) in enumerate(w)
        if hasedge(A, σ, l)
            σ = trace(l, A, σ)
        else
            return i - 1, σ
        end
    end
    return length(w), σ
end
