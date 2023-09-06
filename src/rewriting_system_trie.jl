using DataStructures

struct TrieNode{T,U}
    children::Dict{T,trienode}
    kmp_index::Dict{T,Int}
    value::U
end

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
                new_rhs = rewrite!(rule_i, rhs)
                update_rhs!(rule_j, new_rhs)
            end
        end
    end
    return trie
end

function rewrite!(word, trie::Trie)
    # Todo: Implement
end

function rewrite!(word, rule::Pair)
    (lhs, rhs) = rule
    lps = longest_proper_prefix(lhs)

    # Todo: Finish
end