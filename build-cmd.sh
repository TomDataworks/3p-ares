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

ARES_VERSION=1.10.0
ARES_SOURCE_DIR="c-ares"


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
            cp -a "msvc100/cares/lib-debug/libcaresd.lib" \
                "$stage/lib/debug/areslib.lib"
            cp -a "msvc100/cares/lib-release/libcares.lib" \
                "$stage/lib/release/areslib.lib"

            mkdir -p "$stage/include/ares"
            cp -a {ares,ares_dns,ares_version,ares_build,ares_rules}.h \
                "$stage/include/ares/"
        ;;

        "darwin")
            opts="${TARGET_OPTS:--arch i386 -iwithsysroot /Developer/SDKs/MacOSX10.7.sdk -mmacosx-version-min=10.6}"

            # Debug first
            CFLAGS="$opts -g" CXXFLAGS="$opts -g" LDFLAGS="$opts -g" \
                ./configure --prefix="$stage" --libdir="$stage/lib/debug" --includedir="$stage/include/ares" --enable-debug
            make
            make install

            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # There's no real unit test but we'll invoke the 'adig' example
                ./adig secondlife.com
            fi

            make distclean

            # Release last
            CFLAGS="$opts" CXXFLAGS="$opts" LDFLAGS="$opts" \
                ./configure --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include/ares" --enable-optimize
            make
            make install

            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # There's no real unit test but we'll invoke the 'adig' example
                ./adig secondlife.com
            fi

            # Use Release as source of includes
            mkdir -p "$stage/include/ares"
            cp -a {ares,ares_dns,ares_version,ares_build,ares_rules}.h \
                "$stage/include/ares/"

            make distclean
        ;;

        "linux")
            # Prefer gcc-4.6 if available.
            if [[ -x /usr/bin/gcc-4.6 && -x /usr/bin/g++-4.6 ]]; then
                export CC=/usr/bin/gcc-4.6
                export CXX=/usr/bin/g++-4.6
            fi

            # Default target to 32-bit
            opts="${TARGET_OPTS:--m32}"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            # Debug first
            LDFLAGS="$opts -g" CFLAGS="$opts -g" CXXFLAGS="$opts -g" \
                ./configure --prefix="$stage" --libdir="$stage/lib/debug" --includedir="$stage/include/ares" --enable-debug
            make
            make install

            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # There's no real unit test but we'll invoke the 'adig' example
                ./adig secondlife.com
            fi

            make distclean

            # Release last
            LDFLAGS="$opts" CFLAGS="$opts" CXXFLAGS="$opts" \
                ./configure --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include/ares" --enable-optimize
            make
            make install

            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # There's no real unit test but we'll invoke the 'adig' example
                ./adig secondlife.com
            fi

            # Use Release as source of includes
            mkdir -p "$stage/include/ares"
            cp -a {ares,ares_dns,ares_version,ares_build,ares_rules}.h \
                "$stage/include/ares/"

            make distclean
        ;;
    esac
    
    mkdir -p "$stage/LICENSES"
    # copied from http://c-ares.haxx.se/license.html
    cp -a ../c-ares-license.txt "$stage/LICENSES/c-ares.txt"
popd

pass

