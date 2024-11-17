module Words

export AbstractWord, Word
export isprefix, issuffix, suffixes

include("interface.jl")
include("words_impl.jl")
include("bufferwords.jl")
include("searchindex.jl")

# copyto! performance (??)
# Base.copyto!(w::Word, v::Word) = (Base.copyto!(w.ptrs, v.ptrs); w)
# function Base.copyto!(w::Word, v::BufferWord)
#     Base.copyto!(w.ptrs, @view v.storage[v.lidx:v.ridx])
#     return w
# end
# function Base.copyto!(w::BufferWord, v::Word)
#     @assert internal_length(w) ≥ length(v)
#     Base.copyto!(w.storage, v.ptrs)
#     w.lidx = 1
#     w.ridx = length(v)
#     return w
# end

end
