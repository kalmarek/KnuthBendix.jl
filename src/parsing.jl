using MacroTools

function replace_powering(x)
    if @capture(x, ^(a_, n_))
        args = fill(a, n)
        return :(*($(args...)))
    else
        return x
    end
end

function mult_args!(args, old_expr)
    old_expr isa Symbol && (push!(args, old_expr); return args)
    if old_expr.head === :call && old_expr.args[1] === :*
        for e in @view(old_expr.args[2:end])
            mult_args!(args, e)
        end
    end
    return args
end


### parsing Kbmag input files

struct RwsGAP
    generators::Vector{Symbol}
    inverses::Vector{Int}
    equations::Vector{Pair{Vector{Int}, Vector{Int}}}
    _str::String
end

_entry_regex(key, value) = Regex("\\s*$key\\s*:=\\s*$value,")

function _validate_rws(input::AbstractString)
    rec = r"rec\((?<rec>.*)\);"s
    m = match(rec, input)
    isnothing(m) && throw("file doesn't contain a record: $rec not matched")
    str = m[:rec]

    let str = str
        m = match(_entry_regex("isRWS", "true"), str)
        isnothing(m) && throw("file does not seem to contain an rws: $isrws not matched")
    end
    str
end

function _parse_gens(str::AbstractString)
    r = _entry_regex("generatorOrder", "\\[(?<gens>.*?)\\]")
    m = match(r, str)
    isnothing(m) && error("file does not seem to contain generators: $r not matched")
    return strip.(split(m[:gens], ","))
end

function _parse_inverses(str::AbstractString, gens::AbstractArray{<:AbstractString})
    r = _entry_regex("inverses", "\\[(?<gens>.*?)\\]")
    m = match(r, str)
    isnothing(m) && error("file does not seem to contain inverses: $r not matched")
    invs = strip.(split(m[:gens], ","))

    inv_ptrs = zeros(Int, length(gens))
    if !isempty(inv_ptrs)
        for (i,g) in enumerate(invs)
            k = findfirst(==(g), gens)
            isnothing(k) && continue
            inv_ptrs[i] = k
        end
    end
    return inv_ptrs
end

function _parse_equations(str::AbstractString, gens::AbstractArray{<:AbstractString})
    m = let str = str
        r = r"\s*equations\s*:=\s*(?<equations>\[.*(?!:=)\])"s
        m = match(r, str)
        isnothing(m) && throw("file does not seem to contain equations: $r not matched")
        m
    end

    gens_or = join(gens, "|")
    space = "[\\n\\s]*"
    word_reg = "(($gens_or)(\\*($gens_or|($space($gens_or))))*)"
    eq_r = Regex("\\[$space(?<lhs>$word_reg)$space,$space(?<rhs>IdWord|$word_reg)$space\\]")

    gens_dict = Dict(g=>i for (i,g) in pairs(gens))

    eqns_ptrs = Pair{Vector{Int}, Vector{Int}}[]

    for m in eachmatch(eq_r, m[:equations])
        lhs, rhs = m[:lhs], m[:rhs]
        lhs_ptrs = [gens_dict[strip(g)] for g in split(lhs, "*")]
        rhs_ptrs = if rhs == "IdWord"
            Int[]
        else
            [gens_dict[g] for g in split(rhs, "*")]
        end
        push!(eqns_ptrs, lhs_ptrs => rhs_ptrs)
    end
    length(eqns_ptrs) == 0 && throw("equations := [...] don't seem to contain properly formatted equations: no $eq_r was matched")

    return eqns_ptrs
end


function _parse_equations(str::AbstractString, gens::AbstractArray{<:Symbol})

    m = let str = str
        r = r"\s*equations\s*:=\s*(?<equations>\[.*(?!:=)\])"s
        m = match(r, str)
        isnothing(m) && throw("file does not seem to contain equations: $r not matched")
        m
    end

    eqns_parsed = Meta.parse(m[:equations])
    @assert eqns_parsed.head === :vect
    VI = Vector{Int}
    eqns_ptrs = Vector{Pair{VI, VI}}(undef, length(eqns_parsed.args))
    gens_dict = Dict(s=>i for (i,s) in pairs(gens))

    for (idx, eqn) in enumerate(eqns_parsed.args)
        @assert eqn.head === :vect
        @assert length(eqn.args) == 2
        lhs_ast, rhs_ast = eqn.args

        tmp = Symbol[]
        lhs_ptrs = let expr = lhs_ast, tmp=tmp
            ex = MacroTools.postwalk(replace_powering, expr)
            [gens_dict[g] for g in mult_args!(tmp, ex)]
        end
        resize!(tmp, 0)
        rhs_ptrs = let expr = rhs_ast, tmp=tmp
            ex = MacroTools.postwalk(replace_powering, expr)
            args = mult_args!(tmp, ex)
            args == [:IdWord] ? Int[] : [gens_dict[g] for g in args]
        end

        eqns_ptrs[idx] = lhs_ptrs=>rhs_ptrs
    end
    return eqns_ptrs
end

function parse_kbmag(input::AbstractString; method=:ast)

    @assert method in (:ast, :string)

    rws_str = _validate_rws(input)

    gens = _parse_gens(rws_str)
    inverses = _parse_inverses(rws_str, gens)
    equations = if method === :ast
        _parse_equations(rws_str, Symbol.(gens))
    elseif method === :string
        _parse_equations(rws_str, gens)
    end

    return RwsGAP(Symbol.(gens), inverses, equations, rws_str)
end

RewritingSystem(rwsgap::RwsGAP) = RewritingSystem{Word{UInt16}}(rwsgap)

function RewritingSystem{W}(rwsgap::RwsGAP) where W
    A = Alphabet(rwsgap.generators, rwsgap.inverses)
    rwrules = [W(l)=>W(r) for (l,r) in rwsgap.equations]
    return RewritingSystem(rwrules, LenLex(A))
end
