function rwsfromfile(filepath; method = :string)
    @assert isfile(filepath)
    filecontent = read(filepath, String)
    kbmag_rws = KnuthBendix.parse_kbmag(filecontent, method = method)
    rws = RewritingSystem(kbmag_rws)
    return rws
end

function rwsfiles(kb_data_path)
    @assert isdir(kb_data_path)
    files = readdir(kb_data_path)
    filter!(fn -> match(r"(.*)\.(kbprog|ec|reduce)", fn) === nothing, files)
    return files
end

function clean_kbprog(file)
    for fn in ("$file.kbprog", "$file.kbprog.ec", "$file.reduce")
        isfile(fn) && rm(fn)
    end
end

# The default parameters were obtained from
# gap-packages.github.io/kbmag/doc/chap2_mj.html#X7BB411528630D4E9
const kbmag_settings = KnuthBendix.Settings(
    max_rules = 32767,    # maxeqns
    confluence_delay = 500,      # confnum
    max_length_rhs = 0,        # (max_rhs, _)
    max_length_lhs = 0,        # (_, max_lhs)
    max_length_overlap = 0,        # maxoverlaplen
)
