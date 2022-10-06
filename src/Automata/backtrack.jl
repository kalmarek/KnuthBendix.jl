mutable struct BacktrackSearch{S,At<:Automaton{S}}
    automaton::At
    tape::Vector{S}
    stack::Vector{Int}
    max_age::UInt

    function BacktrackSearch(at::Automaton{S}) where {S}
        return new{S,typeof(at)}(
            at,
            Vector{S}(),
            Vector{Int}(),
            typemax(UInt)
        )
    end
end

function _backtrack_oracle(
    bs::BacktrackSearch,
    β;
    max_age = bs.max_age,
    max_depth=length(signature(bs.automaton, β))
)
    β.data > max_age && return true
    # depth of search exceeds the length of the signature of the last step
    # equivalently the length of completed word is greater or equal to length(lhs)
    # i.e. the completion contains the whole signature so that the overlap of the
    # initial one and terminal is empty
    length(bs.tape)-1 ≥ max_depth && return true
    return false
end

Base.eltype(::Type{<:BacktrackSearch{S}}) where S = S
Base.IteratorSize(::Type{<:BacktrackSearch}) = Base.SizeUnknown()

function initialize!(bs::BacktrackSearch, β = initial(bs.automaton))
    resize!(bs.tape, 1)
    resize!(bs.stack, 0)
    bs.tape[begin] = β
    return bs
end

function (bs::BacktrackSearch)(w::AbstractWord; max_age::Integer=typemax(UInt))
    l,β = trace(w, bs.automaton, initial(bs.automaton))
    @assert l == length(w)
    bs = initialize!(bs, β)
    bs.max_age = max_age
    return bs
end

function Base.iterate(bs::BacktrackSearch, backtracking = false)
    if backtracking
        backtrack = true
        @goto BACKTRACKING
    else
        backtrack = false
    end

    while !isempty(bs.tape) && !backtrack
        backtrack = _backtrack_oracle(bs, bs.tape[end])
        # @info "initial info: β = $(id(bs.tape[end]))"
        # @info "oracle says: backtrack = $backtrack"
        if !backtrack && isterminal(bs.automaton, bs.tape[end])
            # @warn "found a terminal state" bs.tape[end]
            return bs.tape[end], true
        end
        if !backtrack
            # @info bs.stack
            push!(bs.stack, 1)
            β_next = trace(bs.stack[end], bs.automaton, bs.tape[end])
            push!(bs.tape, β_next)
            # @info "descending the search tree with $(bs.stack[end])"
            # @info bs.stack
        else
            @label BACKTRACKING
            # @info "exploring the current level"
            md = max_degree(initial(bs.automaton))

            while backtrack && length(bs.tape) > 1
                # @info bs.stack
                if bs.stack[end] < md
                    # @info "going to the next child"
                    bs.stack[end] += 1 # pick next letter
                    β_prev = bs.tape[end-1]
                    bs.tape[end] = trace(bs.stack[end], bs.automaton, β_prev)
                    backtrack = false
                else
                    # @info "explored all children, backtracking"
                    pop!(bs.tape)
                    pop!(bs.stack)
                end
                # @info bs.stack
            end
        end
    end
    return nothing
end
