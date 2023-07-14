using KnuthBendix

function rwsfromfile(filepath)
    filecontent = String(read(filepath))
    return RewritingSystem(KnuthBendix.parse_kbmag(filecontent, method = :string))
end
