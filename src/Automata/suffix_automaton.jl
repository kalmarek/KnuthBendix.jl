mutable struct SuffixState{I}
    transitions::Vector{Tuple{I,SuffixState{I}}}
    length::Int
    suffix_link::SuffixState{I}
    terminal::Bool

    function SuffixState{I}(length = 0) where {I}
        state = new{I}(Vector{Tuple{I,SuffixState{I}}}(), length)
        state.terminal = false
        return state
    end
    function SuffixState(st::SuffixState{I}, length::Integer) where {I}
        state = new{I}(copy(st.transitions), length, suffix(st), false)
        return state
    end
end

function hasedge(st::SuffixState{I}, i::J) where {J,I<:J}
    return findfirst(p -> first(p) == i, st.transitions) ≠ nothing
end
isterminal(st::SuffixState) = st.terminal
isfail(st::SuffixState) = !isdefined(st, :suffix_link)

function setsuffix!(st::SuffixState, suffix::SuffixState)
    @assert length(suffix) < length(st)
    # @debug "setting suffix link: $st  →  $suffix"
    return st.suffix_link = suffix
end
suffix(st::SuffixState) = st.suffix_link
Base.length(st::SuffixState) = st.length

Base.@propagate_inbounds function Base.getindex(
    st::SuffixState{I},
    i::J,
) where {J,I<:J}
    k = findfirst(p -> first(p) == i, st.transitions)
    @assert k !== nothing

    return last(st.transitions[k])
end

function Base.setindex!(st::SuffixState{I}, v::SuffixState{I}, i::I) where {I}
    if (k = findfirst(p -> first(p) == i, st.transitions)) === nothing
        push!(st.transitions, (i, v))
    else
        st.transitions[k] = (i, v)
    end
end

function Base.show(io::IO, st::SuffixState{I}) where {I}
    if length(st) == -1
        print(io, "fail state")
    else
        if length(st) == 0
            print(io, "initial state (")
        else
            isterminal(st) && print(io, "terminal ")
            print(io, "$(length(st))-state (")
            if isdefined(st, :suffix_link)
                print(io, " $(length(suffix(st)))-suffix;")
            else
                print(io, " no suffix;")
            end
        end
        l = length(st.transitions)
        if l > 0
            print(io, " ", l, " transition", l ≠ 1 ? "s" : "", ": ")
            join(io, keys(st.transitions), ", ", " and ")

        else
            print(io, " no transitions")
        end
        print(io, " )")
    end
end

struct SuffixAutomaton{S} <: Automaton{S}
    initial::S
    fail::S

    function SuffixAutomaton(::Type{I}) where {I}
        init = SuffixState{I}(0)
        fail = SuffixState{I}(-1)
        setsuffix!(init, fail)
        return new{typeof(init)}(init, fail)
    end
end

initial(sfxA::SuffixAutomaton) = sfxA.initial
hasedge(::SuffixAutomaton{S}, st::S, label) where {S} = hasedge(st, label)
function addedge!(::SuffixAutomaton{S}, src::S, dst::S, label) where {S}
    @assert length(src) < length(dst)
    # @debug "adding edge link: $src  -($label)→  $dst"
    return src[label] = dst
end
isfail(sfxA::SuffixAutomaton{S}, st::S) where {S} = st == sfxA.fail
isterminal(::SuffixAutomaton{S}, st::S) where {S} = isterminal(st)
Base.Base.@propagate_inbounds function trace(
    label::I,
    ::SuffixAutomaton{S},
    st::S,
) where {I,S<:SuffixState{I}}
    return st[label]
end

function addstate!(
    sfxA::SuffixAutomaton{S},
    last::S,
    letter::I,
) where {I,S<:SuffixState{I}}
    current = S(length(last) + 1)
    @assert !isfail(sfxA, last)
    # @debug "extending sfxA with letter = $letter" last
    p = last
    while !isfail(sfxA, p) && !hasedge(sfxA, p, letter)
        addedge!(sfxA, p, current, letter)
        p = suffix(p)
    end

    if isfail(sfxA, p)
        # @debug "reached the root of the suffix tree"
        setsuffix!(current, initial(sfxA))
        return sfxA, current
    end

    # @debug "found p → q labeled by $letter"

    q = @inbounds trace(letter, sfxA, p)
    @assert isdefined(q, :suffix_link)

    if length(p) + 1 == length(q)
        # @debug "p → q suffix link is simple"
        setsuffix!(current, q)
    else
        # @debug "p → q suffix link is compressed"
        # we splice clone just above p between p and q:
        clone = SuffixState(q, length(p) + 1)
        # @debug "cloned:" q clone

        while !isfail(sfxA, p) &&
                  hasedge(sfxA, p, letter) &&
                  trace(letter, sfxA, p) == q
            addedge!(sfxA, p, clone, letter)
            p = suffix(p)
        end

        setsuffix!(current, clone)
        setsuffix!(q, clone)

        # @assert trace(letter, sfxA, clone) == current
        @assert suffix(current) == clone
        @assert suffix(q) == clone
    end
    return sfxA, current
end

function SuffixAutomaton(itr)
    I = eltype(itr)
    sfxA = SuffixAutomaton(I)

    last = initial(sfxA)

    for letter in itr
        sfxA, last = addstate!(sfxA, last, letter)
    end

    # mark the appropriate states as terminal
    while !isfail(sfxA, last)
        last.terminal = true
        @assert length(last) > length(suffix(last))
        last = suffix(last)
    end
    return sfxA
end
