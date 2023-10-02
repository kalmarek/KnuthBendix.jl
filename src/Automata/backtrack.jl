"""
    BacktrackSearch{S, A<:Automaton{S}}
Struct for backtrack searches inside automatons.

The backtrack oracle must be provided as a function

    oracle(bts::BacktrackSearch, current_state)::Bool

`oracle` may read e.g the current path (`bts.tape`) of states inside the
`bts.automaton::Automaton` but should never modify those objects.
By default `oracle` is a function that always returns `false`.

If backtrack searches are required from a particular state of `bts.automaton`,
[`initialize!()`](@ref) function should be used to set this.
"""
mutable struct BacktrackSearch{S,At<:Automaton{S}}
    automaton::At
    initial_st::S
    tape::Vector{S}
    oracle::Function

    function BacktrackSearch(
        at::Automaton{S},
        oracle = _default_oracle(at),
        initial_st = initial(at),
    ) where {S}
        return new{S,typeof(at)}(
            at,
            initial_st,
            [initial_st],
            oracle,
        )
    end
end

_default_oracle(::Automaton) = (args...) -> false
_default_oracle(::IndexAutomaton) = _confluence_oracle

Base.eltype(::Type{<:BacktrackSearch{S}}) where {S} = S
Base.IteratorSize(::Type{<:BacktrackSearch}) = Base.SizeUnknown()

"""
    initialize!(bts::BacktrackSearch
        [, state=initial(bts.automaton), oracle = bts.oracle])
Initialize backtrack search at a given `state` with backtrack `oracle`.
"""
function reinitialize!(
    bts::BacktrackSearch{S},
    state::S = bts.initial_st,
    oracle::Function = bts.oracle,
) where {S}
    resize!(bts.tape, 1)
    bts.tape[begin] = state
    bts.oracle = oracle
    return bts
end

function _confluence_oracle(
    bs::BacktrackSearch,
    current_state;
)
    current_depth = length(signature(bs.automaton, current_state))
    # depth of search exceeds the length of the signature of the last step
    # equivalently the length of completed word is greater or equal to length(lhs)
    # i.e. the completion contains the whole signature so that the overlap of the
    # initial one and terminal is empty
    current_depth < length(bs.tape) && return true
    return false
end

"""
    (bts::BacktrackSearch)(w::AbstractWord, oracle=bts.oracle)
Trace `w` through `bts.automaton` and initialize `bts` at the resulting state.
"""
function (bts::BacktrackSearch)(w::AbstractWord, oracle::Function = bts.oracle)
    l, β = trace(w, bts.automaton, initial(bts.automaton))
    @assert l == length(w)
    return reinitialize!(bts, β, oracle)
end

function Base.iterate(bts::BacktrackSearch, (stack, backtrack) = (Int[], false))
    backtrack && @goto BACKTRACK

    while !isempty(bts.tape) && !backtrack
        backtrack = bts.oracle(bts, bts.tape[end])
        # @info "initial info: β = $(id(bs.tape[end]))"
        # @info "oracle says: backtrack = $backtrack"
        if !backtrack && isterminal(bts.automaton, bts.tape[end])
            # @warn "found a terminal state" bs.tape[end]
            return bts.tape[end], (stack, true)
        end
        if !backtrack
            push!(stack, 1)
            β_next = trace(stack[end], bts.automaton, bts.tape[end])
            push!(bts.tape, β_next)
            # @info "descending the search tree with $(bs.stack[end])"
            # @info bs.stack
        else
            @label BACKTRACK
            # @info "exploring the current level"
            md = max_degree(initial(bts.automaton))

            while backtrack && length(bts.tape) > 1
                # @info bs.stack
                if stack[end] < md
                    # @info "going to the next child"
                    stack[end] += 1 # pick next letter
                    prev_st = bts.tape[end-1]
                    bts.tape[end] = trace(stack[end], bts.automaton, prev_st)
                    backtrack = false
                else
                    # @info "explored all children, backtracking"
                    pop!(bts.tape)
                    pop!(stack)
                end
                # @info bs.stack
            end
        end
    end
    reinitialize!(bts) # reset the bts to its original state
    return nothing
end
