using DataStructures

mutable struct AhoCorasickNode
    next::Dict{Char, AhoCorasickNode}
    fail::Union{AhoCorasickNode, Nothing}
    output::Vector{String}
end

function AhoCorasickNode()
    return AhoCorasickNode(Dict{Char, AhoCorasickNode}(), nothing, [])
end

mutable struct AhoCorasickAutomaton
    root::AhoCorasickNode
end

function AhoCorasickAutomaton()
    return AhoCorasickAutomaton(AhoCorasickNode())
end

function push!(automaton::AhoCorasickAutomaton, pattern::String)
    node = automaton.root

    for char in pattern
        if !haskey(node.next, char)
            node.next[char] = AhoCorasickNode()
        end
        node = node.next[char]
    end

    push!(node.output, pattern)
end

function build_fail_transitions!(automaton::AhoCorasickAutomaton)
    queue = Deque{AhoCorasickNode}()
    root = automaton.root

    # Initialize failure links for level 1 nodes (direct children of the root)
    for (char, child) in root.next
        child.fail = root
        push!(queue, child)
    end

    while !isempty(queue)
        node = popfirst!(queue)

        for (char, child) in node.next
            candidate = node.fail

            while candidate != root && !haskey(candidate.next, char)
                candidate = candidate.fail
            end

            if haskey(candidate.next, char)
                child.fail = candidate.next[char]
            else
                child.fail = root
            end

            # Merge child's output with its fail node's output
            child.output = vcat(child.output, child.fail.output)
            push!(queue, child)
        end
    end
end

function search(automaton::AhoCorasickAutomaton, text::String)
    node = automaton.root
    results = Dict{String, Vector{Int}}()

    for (i, char) in enumerate(text)
        while node != automaton.root && !haskey(node.next, char)
            node = node.fail
        end

        if haskey(node.next, char)
            node = node.next[char]
        end

        for pattern in node.output
            if !haskey(results, pattern)
                results[pattern] = []
            end
            push!(results[pattern], i - length(pattern) + 1)
        end
    end

    return results
end

automaton = AhoCorasickAutomaton()
push!(automaton, "he")
push!(automaton, "she")
push!(automaton, "his")
push!(automaton, "hers")
build_fail_transitions!(automaton)

search(automaton, "hershe")