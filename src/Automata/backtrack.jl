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

## particular BacktrackOracles

struct ConfluenceOracle <: BacktrackOracle end
function Base.eltype(
    ::Type{ConfluenceOracle},
    ::Type{<:BacktrackSearch{S}},
) where {S}
    return valtype(S)
end

function return_value(::ConfluenceOracle, bts::BacktrackSearch)
    return value(last(bts.history)) # return the rule of the terminal state
end

function (::ConfluenceOracle)(bts::BacktrackSearch)
    current_state = last(bts.history)
    path_len = length(signature(bts.automaton, current_state))

    terminal = isterminal(bts.automaton, current_state)
    skew_path = path_len < length(bts.history)

    # backtrack when the depth of search exceeds the length of the signature of
    # the last step
    # Equivalently: the length of completed word is greater or equal to
    # length(lhs) so that the suffix contains the whole signature which means
    # that the overlap of the initial word and the suffix is empty.
    # OR we reached a terminal state
    bcktrck = terminal || skew_path

    # we return only the terminal states
    rtrn = terminal && !skew_path

    return bcktrck, rtrn
end

mutable struct LoopSearchOracle <: BacktrackOracle
    n_visited::UInt
    max_depth::UInt
    LoopSearchOracle() = new(0, 0)
end

function __reset!(lso::LoopSearchOracle)
    lso.n_visited = 0
    lso.max_depth = 0
    return lso
end

function Base.eltype(
    ::Type{LoopSearchOracle},
    ::Type{<:BacktrackSearch{S}},
) where {S}
    return S
end

return_value(::LoopSearchOracle, bts::BacktrackSearch) = last(bts.history)

function (oracle::LoopSearchOracle)(bts::BacktrackSearch)
    current_state = last(bts.history)
    # backtrack on terminal states (leafs)
    bcktrck = isterminal(bts.automaton, current_state)
    if !bcktrck
        oracle.n_visited += 1
        oracle.max_depth = max(oracle.max_depth, length(bts.history) - 1)
    end

    # return when loop is found
    rtrn = current_state in @view bts.history[1:end-1]
    # the loop can be read of bs.tape or stack returned by Base.iterate(bts)

    return bcktrck, rtrn
end

mutable struct IrreducibleWordsOracle <: BacktrackOracle
    min_length::UInt
    max_length::UInt
    function IrreducibleWordsOracle(min_length = 0, max_length = typemax(UInt))
        return new(min_length, max_length)
    end
end

function Base.eltype(
    ::Type{IrreducibleWordsOracle},
    ::Type{<:BacktrackSearch{S,A}},
) where {S,A}
    return word_type(A)
end

function return_value(oracle::IrreducibleWordsOracle, bts::BacktrackSearch)
    @assert length(bts.path) - 1 ≤ oracle.max_length
    return word_type(bts.automaton)(@view(bts.path[1:end]), false)
end

function (oracle::IrreducibleWordsOracle)(bts::BacktrackSearch)
    current_state = last(bts.history)
    leaf_node = isterminal(bts.automaton, current_state)
    bcktrck = leaf_node || length(bts.path) > oracle.max_length

    length_fits = oracle.min_length ≤ length(bts.path) ≤ oracle.max_length
    rtrn = !leaf_node && length_fits
    return bcktrck, rtrn
end

"""
    infiniteness_certificate(ia::IndexAutomaton)
Find a family of irreducible words of unbounded length if it exists.

Returns a witness `w` of the infiniteness, i.e.
```
    [w.prefix * w.suffix^n for n in ℕ]
```
is an infinite family of words _irreducible_ with respect to `ia`.

Conversly if `w.suffix` is the trivial word no such infinite family exists and
therefore the there are only finitely many irreducible words for `ia`.
"""
function infiniteness_certificate(ia::IndexAutomaton)
    W = word_type(ia)
    bts = BacktrackSearch(ia, LoopSearchOracle())
    val = iterate(bts)

    if isnothing(val)
        return (prefix = one(W), suffix = one(W))
    else
        h = bts.history
        k = something(findfirst(==(last(h)), @view h[1:end-1]), 1)
        return (
            prefix = W(bts.path[2:k-1], false),
            suffix = W(bts.path[k:end], false),
        )
    end
end

function Base.isfinite(ia::IndexAutomaton)
    certificate = infiniteness_certificate(ia)
    return isone(certificate.suffix)
end

function nirreducible_words(ia::Automaton)
    oracle = LoopSearchOracle()
    res = iterate(BacktrackSearch(ia, oracle))
    if isnothing(res)
        return oracle.n_visited
    end
    throw(InexactError(:nirreducible_words, UInt, Inf))
end

function irreducible_words(ia::Automaton)
    oracle = LoopSearchOracle()
    res = iterate(BacktrackSearch(ia, oracle))
    if isnothing(res)
        bs = BacktrackSearch(ia, IrreducibleWordsOracle())
        irr_w = Vector{eltype(bs)}(undef, oracle.n_visited)
        for (i, w) in enumerate(bs)
            irr_w[i] = w
        end
        return irr_w
    end
    throw("The language of irreducible words of the Automaton is infinite.")
end

function irreducible_words(ia::Automaton, min_lenght::Int, max_length::Int)
    oracle = IrreducibleWordsOracle(min_lenght, max_length)
    bs = BacktrackSearch(ia, oracle)
    return collect(bs)
end
