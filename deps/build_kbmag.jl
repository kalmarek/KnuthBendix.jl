using Libdl

# constant directories
const download_dir = joinpath(@__DIR__, "..", "deps", "kbmag", "downloads");       mkpath(download_dir)
const sources_dir = joinpath(@__DIR__, "..", "deps", "kbmag", "src");              mkpath(sources_dir)
const patches_dir = joinpath(@__DIR__, "..", "deps", "kbmag", "patches");          mkpath(patches_dir)
const target_lib_dir = joinpath(@__DIR__, "..", "deps", "kbmag", "usr", "lib");    mkpath(target_lib_dir)
const target_bin_dir = joinpath(@__DIR__, "..", "deps", "kbmag", "usr", "bin");    mkpath(target_bin_dir)

# common functions
function getsources(src_uri, destination, force=false)
    if force || !isfile(destination)
        download(src_uri, destination)
    end
end

function unpack(source_tarball, destination_dir, force=false)
    unpack_dir = joinpath(destination_dir, split(basename(source_tarball),".")[1])
    if force || !isdir(unpack_dir)
        run(`tar -xvzf $source_tarball -C $destination_dir`)
    end
end

function build(build_dir, make_target, force=false; j=4)
    current_dir = pwd()
    cd(build_dir)
    force && run(`make clean`)
    run(`make -j$j $make_target`)
    cd(current_dir)
end

function patch(package)
    patch_dir = joinpath(patches_dir, package)
    if isdir(patch_dir)
        run(`cp -Rf $patch_dir $sources_dir`)
    end
end

# kbmag dependency
function installkbmag(version::VersionNumber, force=false)
    src_uri = "https://github.com/gap-packages/kbmag/releases/download/v$version/kbmag-$version.tar.gz"

    if force
        sources = joinpath(download_dir, "kbmag-$version.tar.gz")
        getsources(src_uri, sources, force)
        unpack(sources, sources_dir, force)
    end

    standalone_lib_dir      = joinpath(sources_dir, "kbmag-$version", "standalone", "lib")
    standalone_sources_dir  = joinpath(sources_dir, "kbmag-$version", "standalone", "src")
    standalone_bin_dir      = joinpath(sources_dir, "kbmag-$version", "standalone", "bin");   mkpath(standalone_bin_dir)

    target_lib              = joinpath(target_lib_dir, "fsalib.$(Libdl.dlext)")

    # static lib (step 1)
    if force || !isfile(target_lib)
        build(standalone_lib_dir, "fsalib.a", force)
    end

    # binary files (step 2)
    if force
        build(standalone_sources_dir, "all", force)
        mv(standalone_bin_dir, target_bin_dir, force=true)
    end

    # dynamic lib (step 3)
    if force || !isfile(target_lib)
        patch("kbmag-$version")
        build(standalone_lib_dir, "fsalib.$(Libdl.dlext)", force)
        mv(joinpath(standalone_lib_dir, "fsalib.$(Libdl.dlext)"), target_lib, force=true)
    end
end

# download and build dependencies
installkbmag(v"1.5.11", true)