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

echo "${ARES_VERSION}" > "${stage}/VERSION.txt"

pushd "$ARES_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
            load_vsvars

            # apply patch to add getnameinfo support
            #patch -p1 < "../ares-getnameinfo.patch"

            nmake /f Makefile.msvc CFG=lib-debug
            nmake /f Makefile.msvc CFG=lib-release

            mkdir -p "$stage/lib"/{debug,release}
            cp -a "msvc140/cares/lib-debug/libcaresd.lib" \
                "$stage/lib/debug/areslib.lib"
            cp -a "msvc140/cares/lib-release/libcares.lib" \
                "$stage/lib/release/areslib.lib"

            mkdir -p "$stage/include/ares"
            cp -a {ares,ares_dns,ares_version,ares_build,ares_rules}.h \
                "$stage/include/ares/"
        ;;

        "windows64")
            load_vsvars

            # apply patch to add getnameinfo support
            #patch -p1 < "../ares-getnameinfo.patch"

            nmake /f Makefile.msvc CFG=lib-debug
            nmake /f Makefile.msvc CFG=lib-release

            mkdir -p "$stage/lib"/{debug,release}
            cp -a "msvc140/cares/lib-debug/libcaresd.lib" \
                "$stage/lib/debug/areslib.lib"
            cp -a "msvc140/cares/lib-release/libcares.lib" \
                "$stage/lib/release/areslib.lib"

            mkdir -p "$stage/include/ares"
            cp -a {ares,ares_dns,ares_version,ares_build,ares_rules}.h \
                "$stage/include/ares/"
        ;;

        "darwin")
            # Select SDK with full path.  This shouldn't have much effect on this
            # build but adding to establish a consistent pattern.
            #
            # sdk=/Developer/SDKs/MacOSX10.6.sdk/
            # sdk=/Developer/SDKs/MacOSX10.7.sdk/
            # sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.6.sdk/
            DEVELOPER=$(xcode-select --print-path)
            sdk="${DEVELOPER}/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk/"

            opts="${TARGET_OPTS:--arch x86_64 -iwithsysroot $sdk -mmacosx-version-min=10.8}"

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
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.8 if available.
            if [[ -x /usr/bin/gcc-4.8 && -x /usr/bin/g++-4.8 ]]; then
                export CC=/usr/bin/gcc-4.8
                export CXX=/usr/bin/g++-4.8
            fi

            # Default target to 32-bit
            opts="${TARGET_OPTS:--m32}"
            JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
            HARDENED="-fstack-protector"
            HARDENED_CPPFLAGS="-D_FORTIFY_SOURCE=2"

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
                ./configure --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/debug" --includedir="\${prefix}/include/ares" --enable-debug
            make -j$JOBS
            make install DESTDIR="$stage"

            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # There's no real unit test but we'll invoke the 'adig' example
                ./adig secondlife.com
            fi

            make distclean

            # Release last
            LDFLAGS="$opts" CFLAGS="$opts $HARDENED" CXXFLAGS="$opts $HARDENED" CPPFLAGS="$HARDENED_CPPFLAGS" \
                ./configure --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/release" --includedir="\${prefix}/include/ares" --enable-optimize
            make -j$JOBS
            make install DESTDIR="$stage"

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
        "linux64")
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.8 if available.
            if [[ -x /usr/bin/gcc-4.8 && -x /usr/bin/g++-4.8 ]]; then
                export CC=/usr/bin/gcc-4.8
                export CXX=/usr/bin/g++-4.8
            fi

            # Default target to 64-bit
            opts="${TARGET_OPTS:--m64}"
            JOBS=`cat /proc/cpuinfo | grep processor | wc -l`
            HARDENED="-fstack-protector"
            HARDENED_CPPFLAGS="-D_FORTIFY_SOURCE=2"

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
                ./configure --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/debug" --includedir="\${prefix}/include/ares" --enable-debug
            make -j$JOBS
            make install DESTDIR="$stage"

            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                # There's no real unit test but we'll invoke the 'adig' example
                ./adig secondlife.com
            fi

            make distclean

            # Release last
            LDFLAGS="$opts" CFLAGS="$opts $HARDENED" CXXFLAGS="$opts $HARDENED" CPPFLAGS="$HARDENED_CPPFLAGS" \
                ./configure --prefix="\${AUTOBUILD_PACKAGES_DIR}" --libdir="\${prefix}/lib/release" --includedir="\${prefix}/include/ares" --enable-optimize
            make -j$JOBS
            make install DESTDIR="$stage"

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

mkdir -p "$stage"/docs/c-ares/
cp -a README.Linden "$stage"/docs/c-ares/

pass

