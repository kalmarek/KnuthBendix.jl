push!(LOAD_PATH, "..")

using KnuthBendix
using Documenter

DocMeta.setdocmeta!(
    KnuthBendix,
    :DocTestSetup,
    :(using KnuthBendix; import Base.Order: lt);
    recursive = true,
)

makedocs(
    sitename = "KnuthBendix.jl",
    repo = Documenter.Remotes.GitHub("kalmarek", "KnuthBendix.jl"),
    authors = "Marek Kaluba <marek.kaluba@kit.edu> and contributors",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://kalmarek.github.io/KnuthBendix.jl",
        assets = String[],
    ),
    modules = [KnuthBendix],
    checkdocs = :none,
    pages = [
        "Home" => "index.md",
        "Theory" => ["theory.md", "knuthbendix_completion.md"],
        "Words and Alphabets" => ["words.md", "alphabets.md", "orders.md"],
        "Rewriting" => ["rewriting.md", "rewriting_system.md"],
        "Knuth-Bendix completion" => [
            "KB_implementations.md",
            "knuthbendix1.md",
            "knuthbendix2.md",
            "knuthbendix_idxA.md",
        ],
        "Automata" => [
            "automata.md",
            "backtrack.md",
            "index_automaton.md",
            "prefix_automaton.md",
            "suffix_automaton.md",
        ],
        "Parsing `kbmag` input files" => "parsing_kbmag.md",
        "Applications" => ["nc_groebner.md", "builtin_examples.md"],
    ],
    warnonly = [:missing_docs, :cross_references],
)

deploydocs(; repo = "github.com/kalmarek/KnuthBendix.jl", devbranch = "master")
