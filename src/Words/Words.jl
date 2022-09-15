module Words

export AbstractWord, Word
export isprefix, issuffix, suffixes

include("interface.jl")
include("words_impl.jl")
include("bufferwords.jl")
include("searchindex.jl")

end
