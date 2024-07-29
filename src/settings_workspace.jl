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
* `stack_size`: Reduce the rws and incorporate new rules into `rws` whenever
  the stack of newly discovered rules exceeds `stack_size`.
* `confluence_delay`: Attempt a confluence check whenever no new critical pairs
  are discovered after `confluence_delay` iterations in the `knuthbendix` main loop.
* `max_length_lhs`: The upper bound on the length of lhs of new rules considered in the algorithm.
  (reserved for future use).
* `max_length_lhs`: The upper bound on the length of rhs of new rules considered in the algorithm.
  (reserved for future use).
* `max_length_overlap`: The upper bound on the overlaps considered when finding new critical pairs.
  (reserved for future use).
* `verbosity`: Specifies the level of verbosity.
"""
mutable struct Settings{CA<:CompletionAlgorithm}
    algorithm::CA
    max_rules::Int
    stack_size::Int
    confluence_delay::Int
    max_length_lhs::Int
    max_length_rhs::Int
    max_length_overlap::Int
    verbosity::Int
    update_progress::Any

    function Settings(
        alg::CompletionAlgorithm;
        max_rules = 10000,
        stack_size = 100,
        confluence_delay = 10,
        max_length_lhs = typemax(Int),
        max_length_rhs = typemax(Int),
        max_length_overlap = typemax(Int),
        verbosity = 0,
    )
        return new{typeof(alg)}(
            alg,
            max_rules,
            stack_size,
            confluence_delay,
            max_length_lhs,
            max_length_rhs,
            max_length_overlap,
            verbosity,
            (args...) -> nothing,
        )
    end
end

Settings(; kwargs...) = Settings(KBIndex(); kwargs...)

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
end

function Workspace(word_t, history, settings::Settings)
    BP_t = RewritingBuffer{eltype(word_t)}
    return Workspace(
        BP_t(deepcopy(history)),
        BP_t(deepcopy(history)),
        settings,
        0,
        0,
    )
end

function Workspace(rws, settings::Settings = Settings())
    return Workspace(word_type(rws), Int[], settings)
end
