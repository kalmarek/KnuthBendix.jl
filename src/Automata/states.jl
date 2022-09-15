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

id(s::State) = s.id
value(s::State) = s.value
setvalue!(s::State, v) = s.value = v

function hasedge(s::State, i::Integer)
    return isassigned(s.transitions, i)
end

function Base.getindex(s::State, i::Integer)
    hasedge(s, i) && return s.transitions[i]
    return nothing
end

Base.setindex!(s::State, v::State, i::Integer) = s.transitions[i] = v

max_degree(s::State) = length(s.transitions)
degree(s::State) = count(i -> hasedge(s, i), 1:max_degree(s))
iscomplete(s::State) = degree(s) == max_degree(s)

transitions(s::State) = (s[i] for i in 1:max_degree(s) if hasedge(s, i))

function Base.show(io::IO, s::State)
    print(io, "State: ", id(s), " (data=", s.data, ")")
end

function Base.show(io::IO, ::MIME"text/plain", s::State)
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
