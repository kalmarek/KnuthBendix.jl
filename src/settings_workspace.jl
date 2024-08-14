abstract type CompletionAlgorithm end

"""
    Settings{CA<:CompletionAlgorithm}
    Settings(alg; kwargs...)
Struct encompassing knobs and switches for the `knuthbendix` completion.

# Arguments:
* `alg::CompletionAlgorithm`: the algorithms used for Knuth-Bendix completion

# Keyword arguments
* `max_rules`: forcefully terminate Knuth-Bendix completion if the number of
   rules exceeds `max_rules`. Note: this is only a hint, the returned `rws` may
   contain more or fewer rewriting rules.
* `reduce_delay`: Reduce the rws (and incorporate new found rules into `rws`)
  whenever the number of discovered rules since last reduction exceeds `reduce_delay`.
* `confluence_delay`: Attempt a confluence check whenever no new critical pairs
  are discovered after considering `confluence_delay` pairs of rules.
* `max_length_lhs`: The upper bound on the length of lhs of new rules considered in the algorithm.
* `max_length_lhs`: The upper bound on the length of rhs of new rules considered in the algorithm.
* `max_length_overlap`: The upper bound on the overlaps considered when finding new critical pairs.
* `collect_dropped`: The discovered critical pairs which are not admissible (
   due to the length limiting options above) will be collected during completion.
   To access those pairs you will need to use `knuthbendix!` function and
   pass `Workspace` directly.
* `verbosity`: Specifies the level of verbosity.

!!! note
    Not all flags have effect for every completion algorithm. E.g. the
    length-limiting and collection will be used only for [`KBIndex`](@ref) and
    [`KBPrefix`](@ref).
"""
mutable struct Settings{CA<:CompletionAlgorithm}
    algorithm::CA
    max_rules::Int
    reduce_delay::Int
    confluence_delay::Int
    max_length_lhs::Int
    max_length_rhs::Int
    max_length_overlap::Int
    verbosity::Int
    collect_dropped::Bool
    update_progress::Any
    # hide the innner constructor
    global function __Settings(
        alg::CompletionAlgorithm;
        max_rules = 10000,
        reduce_delay = 100,
        confluence_delay = 10,
        max_length_lhs = typemax(Int),
        max_length_rhs = typemax(Int),
        max_length_overlap = typemax(Int),
        verbosity = 0,
        collect_dropped = false,
    )
        return new{typeof(alg)}(
            alg,
            max_rules,
            reduce_delay,
            confluence_delay,
            max_length_lhs,
            max_length_rhs,
            max_length_overlap,
            verbosity,
            collect_dropped,
            (args...) -> nothing,
        )
    end
end

Settings(; kwargs...) = Settings(KBIndex(); kwargs...)
function Settings(ca::CompletionAlgorithm, sett::Settings)
    settings = Settings(ca)
    for propn in propertynames(settings)
        if propn in (:algorithm, :update_progress)
            continue
        end
        setproperty!(settings, propn, getproperty(sett, propn))
    end
    return settings
end

function Base.show(io::IO, ::MIME"text/plain", sett::Settings)
    println(io, typeof(sett), ":")
    fns = filter!(≠(:update_progress), collect(fieldnames(typeof(sett))))
    l = mapreduce(length ∘ string, max, fns)
    for fn in fns
        fn == :update_progress && continue
        println(io, rpad(" • $fn", l + 5), " : ", getfield(sett, fn))
    end
end

function isadmissible(lhs, rhs, s::Settings)
    return length(lhs) ≤ s.max_length_lhs && length(rhs) ≤ s.max_length_rhs
end

mutable struct Workspace{CA,T,H,S<:Settings{CA}}
    rewrite1::RewritingBuffer{T,H}
    rewrite2::RewritingBuffer{T,H}
    settings::S
    confluence_timer::Int
    dropped_rules::Int
    dropped_stack::Vector{Tuple{Word{T},Word{T}}}
end

function Workspace(rws, settings::Settings = Settings())
    W = word_type(rws)
    T = eltype(W)
    return Workspace(
        RewritingBuffer{T}(rws),
        RewritingBuffer{T}(rws),
        settings,
        0,
        0,
        Tuple{W,W}[],
    )
end

function Workspace(rws, settings::Settings = Settings())
    return Workspace(word_type(rws), Int[], settings)
end
