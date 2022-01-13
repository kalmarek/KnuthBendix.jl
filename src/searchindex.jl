function _search_bloom_mask(c::Union{Int8,UInt8})
    return UInt64(1) << (c & 63)
end

function _search_bloom_mask(c::Union{Int16,UInt16})
    return UInt128(1) << (c & 127)
end
_bloom_mask(::Type{<:Union{Int8,UInt8}}) = UInt64(0)
_bloom_mask(::Type{<:Union{Int16,UInt16}}) = UInt128(0)

function _bloom_mask(v::AbstractWord{T}) where {T}
    mask = _bloom_mask(T)
    isempty(v) && return mask, -1
    # we can skip by this amount if a single mismatch is found
    skip = length(v) - 1
    @inbounds v_last = v[end]
    for j in 1:length(v)-1
        # mm = _search_bloom_mask(v[j])
        # @info bitstring(mm) typeof(mask)
        mask |= _search_bloom_mask(@inbounds v[j])
        if @inbounds v[j] == v_last
            skip = length(v) - j - 1
        end
    end
    # mm = _search_bloom_mask(v[end])
    # @info bitstring(mm) typeof(mask)
    mask |= _search_bloom_mask(@inbounds v[end])
    return mask, skip
end

function _searchindex(
    word::AbstractWord{<:Union{Int8,UInt8}},
    subword::AbstractWord{<:Union{Int8,UInt8}},
    start::Integer,
)
    isempty(word) && return 0
    isempty(subword) && return max(1, Int(start))

    if length(subword) == 1
        return something(findnext(==(subword[begin]), word, start), 0)
    end

    n = length(subword)
    m = length(word)

    width = m - n
    width < 0 && return 0
    1 ≤ start ≤ width + 1 || return 0

    # prepare bloom_mask
    mask, skip = _bloom_mask(subword)

    s_last = subword[end]
    i = Int(start) - 1
    @inbounds while i <= width
        if word[i+n] == s_last
            # check candidate
            j = 0
            while j < n - 1
                if word[i+j+1] != subword[j+1]
                    break
                end
                j += 1
            end

            # match found
            if j == n - 1
                return i + 1
            end

            # no match, try to rule out the next character
            if i < width && mask & _search_bloom_mask(word[i+n+1]) == 0
                i += n
            else
                i += skip
            end
        elseif i < width
            if mask & _search_bloom_mask(word[i+n+1]) == 0
                i += n
            end
        end
        i += 1
    end

    return 0
end

function _searchindex(word::AbstractWord, subword::AbstractWord, pos::Integer)
    k = length(subword)
    f = first(subword)
    @inbounds for i in pos:length(word)-k+1
        word[i] == f || continue
        issub = true
        @inbounds for j in 2:k
            if word[i+j-1] != subword[j]
                issub = false
                break
            end
        end
        issub == true && return i:i+k-1
    end
    return 1:0
end
