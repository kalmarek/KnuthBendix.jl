abstract type Word{T} <: AbstractVector{T} end



#interface for morphism T->Int
function to_int{T}(t::T) end
#interface for morphism Int->T
function from_int{T}(t::T) end
#interface for ordering on T
function <=(a::T,b::T) end
#empty string as monoid neutral element
Base.one(::Type{Word{T}}) where {T}  = Word(Vector{T}())
#overload for <= that implements word ordering
function <=(a::Word{T},b::Word{T})
#overload for * as concatenation
function *(a::Word{T},b::Word{T}) where {T} Word(a.ptrs+b.ptrs) end
#interface for function that returns actual vector inside word
function data(a::Word{T})

Base.length(w::Word{T}) where {T}  = length(w.ptrs)


#Is there function composition in Julia?
#Is it possible to assign function more or less like this?
#In Haskell I could just make it work
function Base.iterate(w::Word{T}) = data(w) . iterate()

struct WordLexLen{T}<:Word{T}
    ptrs::Vector{T}
end

struct WordLex{T}<:Word{T}
    ptrs::Vector{T}
end

#Julia does not have dependet types, but type constructors
#can be emulated by manually specyfing all inhabitants of type family.
#In this case the type family is {WordLexLen,WordLex}

#This can be though of as one of the "axioms" for Word
function data(a::WordLexLen{T})
  return a.ptrs
end

function data(a::WordLex{T})
  return a.ptrs
end

#This can be though of as another "axiom" for Word
function <=(a::WordLexLen{T},b::WordLexLen{T})
  if length(a) < length(b) return true end
  if length(a) > length(b) return false end
  for (char_in_a,char_in_b) in zip(a,b)
    if char_in_a > char_in_b
      return false
    end
  end
  return true
end

function <=(a::WordLex{T},b::WordLex{T})
  for (char_in_a,char_in_b) in zip(a,b)
    if char_in_a > char_in_b
      return false
    end
  end
  return true
end
