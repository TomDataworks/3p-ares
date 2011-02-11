#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

ARES_VERSION=1.7.1
ARES_SOURCE_DIR="c-ares-$ARES_VERSION"


# load autbuild provided shell functions and variables
eval "$("$AUTOBUILD" source_environment)"

stage="$(pwd)/stage"

pushd "$ARES_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            load_vsvars

            # apply patch to add getnameinfo support
            #patch -p1 < "../ares-getnameinfo.patch"

            nmake /f Makefile.msvc CFG=lib-debug
            nmake /f Makefile.msvc CFG=lib-release


            mkdir -p "$stage/lib"/{debug,release}
            cp "msvc100/cares/lib-debug/libcaresd.lib" \
                "$stage/lib/debug/areslib.lib"
            cp "msvc100/cares/lib-release/libcares.lib" \
                "$stage/lib/release/areslib.lib"
        ;;
        *)
            ./configure --prefix="$stage"
            make
            make install
        ;;
    esac
    
    mkdir -p "$stage/include/ares"
    cp {ares,ares_dns,ares_version,ares_build,ares_rules}.h \
        "$stage/include/ares/"

    mkdir -p "$stage/LICENSES"
	# copied from http://c-ares.haxx.se/license.html
    cp ../c-ares-license.txt "$stage/LICENSES/c-ares.txt"
popd

pass

