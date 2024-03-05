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

function (bts::BacktrackSearch)(w::AbstractWord)
    l, β = trace(w, bts.automaton, initial(bts.automaton))
    @assert l == length(w)
    bts.initial_st = β
    return bts
end

function Base.iterate(bts::BacktrackSearch{S}) where {S}
    # bring bts to a coherent state
    __reset!(bts.oracle)
    resize!(bts.history, 1)
    bts.history[1] = bts.initial_st
    resize!(bts.path, 0)

    # @warn "backtracking starts from" signature(bts.automaton, bts.initial_st)
    backtrack, rtrn = bts.oracle(bts)
    if rtrn
        return return_value(bts), backtrack
    else
        return Base.iterate(bts, backtrack)
    end
end

function Base.iterate(bts::BacktrackSearch, backtrack::Bool)
    @assert length(bts.path) + 1 == length(bts.history)
    while !(isempty(bts.path) && backtrack)
        # @info $(bts.path)
        # advance to the next state
        if !backtrack # go deeper into search
            push!(bts.path, 1)
            current_st = trace(bts.path[end], bts.automaton, bts.history[end])
            push!(bts.history, current_st)
            # @info "extended $(bts.path)"
        else # we do backtracking here
            md = max_degree(initial(bts.automaton))
            while !isempty(bts.path) && backtrack
                if 1 ≤ bts.path[end] < md # go to next child
                    bts.path[end] += 1
                    bts.history[end] =
                        trace(bts.path[end], bts.automaton, bts.history[end-1])
                    backtrack = false
                    # @info "next child $(bts.path)"
                else # go back one level
                    pop!(bts.history)
                    pop!(bts.path)
                    # @info "shortened $(bts.path)"
                end
            end
        end
        # check if the node we arrived at is valuable
        if !isempty(bts.path)
            backtrack, rtrn = bts.oracle(bts)
            # @info "oracle on $path:" bts.tape backtrack rtrn
            rtrn && return return_value(bts), backtrack
        end
    end
    return nothing
end
