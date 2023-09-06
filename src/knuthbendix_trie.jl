function knuthbendixtrie!(
    rws::RewritingSystem{W},
    settings::Settings = Settings(),
) where {W}
    rws = reduce!(rws)
    stack = Vector{Tuple{W,W}}()

    i = firstindex(rws.rules)
    while i ≤ lastindex(rws.rules)
        ri = rws.rules[i]
        while j ≤ i
            rj = rws.rules[j]
            l = length(stack)
            stack = push_critical_pairs!(stack, rws, ri, rj)
            if length(stack) - l > 0 && time_to_reduce()
        end
    end
end

function push_critical_pairs!(stack, rws, ri, rj)

    if ri !== rj

    end
end