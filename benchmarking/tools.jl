using KnuthBendix

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
