"""
    abstract type BacktrackOracle end
Each `Oracle<:BacktrackOracle` should implement the following methods:

1. `(bto::Oracle)(bts::BacktrackSearch)::Tuple{Bool, Bool}`
  which may access (read-only!) the internal fields of `bts::BacktrackSearch`:
  * `bts.automaton::Automaton` is the explored automaton,
  * `bts.history` contains `d+1` states (including the initial one) describing
    the currently explored branch,
  * `bts.path` contains the tracing word of `bts.history` (of length `d`).
2. `return_value(::Oracle, bts::BacktrackSearch)` what should be returned from
  the backtrack search
3. `Base.eltype(::Type{<:Oracle}, ::Type{<:BacktrackSearch})` the type of
  objects returned by `return_value`.

The returned tuple `(bcktrk, rtrn)` indicate if the search should switch to the
backtrack phase and if the currently visited node should be returned.
Note: oracle will not be queried while backtracking so returning is not possible
then.

If needed `MyOracle<:BacktrackOracle` may provide `__reset!(bo::Oracle)`
function to reset (e.g. the performance counters) itself to the initial state.
"""
abstract type BacktrackOracle end

__reset!(bo::BacktrackOracle) = bo

"""
    BacktrackSearch{S, A<:Automaton{S}, O<:BacktrackOracle}
    BacktrackSearch(at::Automaton, oracle::Oracle[, initial_st=initial(at)])
Struct for backtrack searches inside automatons.

The backtrack oracle must be provided as `oracle<:BacktrackOracle`.
For more information see [`BacktrackOracle`](@ref)

Backtrack search starts from `initial_st` and uses `oracle` to prune branches.

Given `bts::BacktrackSearch` and a word `w` one may call
```
    (bts::BacktrackSearch)(w::AbstractWord)
```
to trace `w` through `bts.automaton` and start `bts` at the resulting state.

# Examples
```julia
julia> rws = RWS_Example_237_abaB(4)
rewriting system with 8 active rules.
[...]

julia> R = knuthbendix(rws)
reduced, confluent rewriting system with 40 active rules.
[...]

julia> bts = BacktrackSearch(IndexAutomaton(R), IrreducibleWordsOracle());

julia> w = Word([1,2,1])

julia> for u in bts(w)
       println(w*u)
       end
1·2·1
1·2·1·2
1·2·1·2·1
1·2·1·2·1·2
1·2·1·2·1·2·1
[...]

```
"""
mutable struct BacktrackSearch{S,At<:Automaton{S},O<:BacktrackOracle}
    automaton::At
    initial_st::S
    history::Vector{S}
    path::Vector{Int}
    oracle::O

    function BacktrackSearch(
        at::Automaton{S},
        oracle::BacktrackOracle,
        initial_st::S = initial(at),
    ) where {S}
        return new{S,typeof(at),typeof(oracle)}(
            at,
            initial_st,
            [initial_st],
            Int[],
            oracle,
        )
    end
end

Base.IteratorSize(::Type{<:BacktrackSearch}) = Base.SizeUnknown()
Base.eltype(T::Type{<:BacktrackSearch{S,A,O}}) where {S,A,O} = eltype(O, T)
return_value(bts::BacktrackSearch) = return_value(bts.oracle, bts)

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
