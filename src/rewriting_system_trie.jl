using DataStructures

struct TrieNode{T,U}
    children::Dict{T,TrieNode}
    kmp_index::Dict{T,Int}
    lps::Int
    rule::U
    isleaf::Bool
    fail_transition::TrieNode
    output::Vector{<:AbstractWord{T}}
end

isleaf(trienode::TrieNode) = trienode.isleaf

struct Trie{W<:AbstractWord{T},U}
    alphabet::Alphabet{T}
    rules::OrderedDict{Int,TrieNode{T}}
    root::trienode{T,U}
    max_depth::Int
end

root(trie::Trie) = trie.root

function push!(trie::Trie, word <: AbstractWord)
    depth = push!(root(trie), @view word[begin:end])
    trie.max_depth = max(trie.max_depth, depth)
    return trie
end

function push!(trienode, word, depth = 0)
    if length(word) > 0
        w = word[1]
        if haskey(trienode.children, w)
            push!(trienode.children[w], @view word[2:end], depth + 1)
        else
            new_trienode = TrieNode{T,U}()
            trienode.children[w] = new_trienode
            push!(new_trienode, @view word[2:end], depth + 1)
        end
    end
    return depth
end

function apply(operations)
    for (f, arguments) in Iterators.reverse(operations)
        f(arguments...)
    end
end

function firstmatch(trienode::TrieNode, word)
    if length(word) > 0
        w = word[1]
        if haskey(trienode.children, w)
            return firstmatch(trienode.children[w], @view word[2:end])
        else
            return nothing
        end
    else
        return trienode.value
    end
end

firstmatch(trie::Trie, word) = firstmatch(trie.root, @view word[begin:end])

"""
Accelerating data structure for the Knuth-Morris-Pratt algorithm.
Given a pattern p, lps[i] is the length of the longest proper prefix
of p[begin:i] that is also a suffix of p[begin:i].
"""
function longest_proper_prefix(pattern)
    l = length(pattern)
    lps = zeros(Int, l)
    substring_length = 0
    for i in 2:l
        if pattern[i] == pattern[substring_length+1]
            substring_length += 1
            lps[i] = substring_length
        else
            if substring_length == 0
                lps[i] = 0
            else
                substring_length = lps[substring_length]
            end
        end
    end
    return lps
end

# Todo: this also has to update trie.rules properly, multiple rules may be deleted by a single empty!(...)
function delete!(trienode, lps, pattern, pattern_index = 1)
    for (letter, nextnode) in trienode.children
        if letter == pattern[pattern_index]
            pattern_index += 1
        end

        if pattern_index == length(pattern) + 1
            # found match, no need to further recurse, all deeper matches will be deleted
            empty!(trienode.children)
        elseif length(trienode.children) > 0 && letter != pattern[pattern_index]
            if pattern_index != 1
                pattern_index = lps[pattern_index-1] + 1
                delete!(trienode, lps, pattern, pattern_index)
            else
                delete!(nextnode, lps, pattern, pattern_index)
            end
        end
    end
    return trienode
end

"""
Use Knuth-Morris-Pratt to remove all rules with a left-hand side containing word.
"""
function delete!(trie::Trie, word)
    lps = longest_proper_prefix(word)
    delete!(trie.root, lps, word)
    return trie
end

function reduce!(trie::Trie)
    rules = trie.rules
    for (i, rule_i) in rules
        simplify!(rule_i..., trie.alphabet)
        for j in 1:i-1
            rule_j = rules[j]
            (lhs, rhs) = rule_j
            if occursin(first(rule_i), lhs)
                delete!(trie, lhs)
            elseif occursin(first(rule_i), rhs)
                new_rhs = rewrite(rhs, rule_i)
                update_rhs!(rule_j, new_rhs)
            end
        end
    end
    return trie
end

function build_fail_transitions!(trie::Trie)
    queue = Deque{TrieNode}()
    root = root(trie)

    for (_, nextnode) in root.children
        push!(queue, nextnode)
    end

    while !isempty(queue)
        node = popfirst!(queue)
        candidate = node.fail_transition

        for (t, childnode) in node.children
            while fail_candidate != root && !haskey(candidate.children, t)
                candidate = candidate.fail
            end

            if haskey(candidate.next, t)
                childnode.fail = candidate.next[t]
            else
                child.fail = root
            end

            child.output = vcat(child.output, child.fail_transition.output)
            push!(queue, child)
        end
    end

    return trie
end

"""
Use Aho-Corasick to find position-rule pairs and rewrite v at these positions.
"""
function rewrite!(v::W, w::W, trie::Trie) where {W}
    build_fail_transitions!(trie)
    results = Dict{Int,Rule}()
    node = root(trie)

    for (i, char) in enumerate(v)
        while node != root(trie) && haskey(node.next, char)
            node = node.fail
        end

        if haskey(node.children, char)
            node = node.children[char]
        end

        for pattern in node.output
            results[i - length(pattern) + 1] = node.rule
        end
    end

    return rewrite!(v, w, results)
end

rewrite(v::W, trie::Trie) where {W} = rewrite!(v, W(), trie)

"""
Rewrite word `w` storing the result in `v` using a single rewriting `rule`.
This variant is based on the KMP algorithm as described by Cormen et. al. p. 926
"""
function rewrite_kmp!(v::AbstractWord, w::AbstractWord, rule::Rule)
    (lhs, rhs) = rule
    lps = longest_proper_prefix(lhs)
    n = length(v)
    m = length(lhs)
    q = 0
    v_pos = 1
    resize!(w, length(v))

    for i in 1:n
        while q > 0 && lhs[q+1] != v[i]
            q = lps[q]
        end
        if lps[q+1] == v[i]
            q += 1
        end
        if q == m  # lhs occurs in v at position i - m
            append!(w, v[v_pos:i-m])
            append!(w, rhs)
            v_pos = i + 1
            q = lps[q]
        end
    end
    return w
end

rewrite_kmp(v::W, rule::Rule) where {W} = rewrite_kmp!(v, W(), rule)

function rewrite!(v::AbstractWord, w::AbstractWord, rewrites::Dict{Int,Rule})
    empty!(w)
    resize!(w, length(v))
    v_pos = 1

    for (position, rule) in rewrites
        (lhs, rhs) = rule
        push!(w, v[v_pos:position])
        push!(w, rhs)
        v_pos += length(lhs) + 1
    end

    return w
end