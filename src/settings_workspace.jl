abstract type CompletionAlgorithm end

mutable struct Settings{CA<:CompletionAlgorithm}
    """The algorithms used for Knuth-Bendix completion"""
    algorithm::CA
    """Terminate Knuth-Bendix completion if the number of rules exceeds `max_rules`."""
    max_rules::Int
    """Reduce the rws and update the indexing automaton whenever the stack
    of newly discovered rules exceeds `stack_size`.
    Note: this is only a hint."""
    stack_size::Int
    """
    Attempt a confluence check whenever no new rules are added to stack after
    `confluence_delay` iterations in the `knuthbendix` main loop.
    """
    confluence_delay::Int
    """Consider only new rules of lhs which does not exceed `max_length_lhs`."""
    max_length_lhs::Int
    """Consider only the new rules of rhs which does not exceed `max_length_rhs`."""
    max_length_rhs::Int
    """When finding critical pairs consider overlaps of length at most `max_overlap_length`."""
    max_lenght_overlap::Int
    """Specifies the level of verbosity"""
    verbosity::Int
    dropped_rules::Bool
    update_progress::Any

    function Settings(
        alg::CompletionAlgorithm;
        max_rules = 10000,
        stack_size = 100,
        confluence_delay = 10,
        max_length_lhs = 100,
        max_length_rhs = 1000,
        max_length_overlap = 0,
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
            false,
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

function Base.filter!(sett::Settings, stack::AbstractVector)
    to_delete = falses(length(stack))
    for i in eachindex(stack)
        to_delete[i] = !isadmissible(stack[i]..., sett)
    end
    if any(to_delete)
        deleteat!(stack, to_delete)
    end
    return stack
end

mutable struct Workspace{CA,T,H,S<:Settings{CA}}
    rewrite1::RewritingBuffer{T,H}
    rewrite2::RewritingBuffer{T,H}
    settings::S
    confluence_timer::Int
end

function Workspace(word_t, history, settings::Settings)
    BP_t = RewritingBuffer{eltype(word_t)}
    return Workspace(
        BP_t(deepcopy(history)),
        BP_t(deepcopy(history)),
        settings,
        0,
    )
end

function Workspace(rws, settings::Settings = Settings())
    return Workspace(word_type(rws), Int[], settings)
end
