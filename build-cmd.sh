#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e

OPENJPEG_VERSION="2.3.1"
OPENJPEG_SOURCE_DIR="src"

if [ -z "$AUTOBUILD" ] ; then 
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

stage="$(pwd)/stage"

# load autobuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${OPENJPEG_VERSION}.${build}" > "${stage}/VERSION.txt"

pushd "$OPENJPEG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            load_vsvars

            cmake . -G "${AUTOBUILD_WIN_CMAKE_GEN}" -DCMAKE_INSTALL_PREFIX=$stage
            build_sln "OPENJPEG.sln" "Release|$AUTOBUILD_WIN_VSPLATFORM" openjp2
            build_sln "OPENJPEG.sln" "Debug|$AUTOBUILD_WIN_VSPLATFORM" openjp2

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"

            cp bin/Release/openjp2{.dll,.lib} "$stage/lib/release"
            cp bin/Debug/openjp2{.dll,.lib} "$stage/lib/debug"

            mkdir -p "$stage/include/openjpeg"

            cp src/lib/openjp2/openjpeg.h "$stage/include/openjpeg"
            cp src/lib/openjp2/opj_stdint.h "$stage/include/openjpeg"
            cp src/lib/openjp2/opj_config.h "$stage/include/openjpeg"
            cp src/lib/openjp2/event.h "$stage/include/openjpeg"
        ;;

        darwin*)
            cmake . -GXcode -D'CMAKE_OSX_ARCHITECTURES:STRING=x86_64' \
                -D'BUILD_SHARED_LIBS:bool=off' -D'BUILD_CODEC:bool=off' \
                -DCMAKE_INSTALL_PREFIX=$stage -DCMAKE_OSX_DEPLOYMENT_TARGET=10.12 \
                -DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.15.sdk
            xcodebuild -configuration Release -target openjp2 -project openjpeg.xcodeproj
            xcodebuild -configuration Release -target install -project openjpeg.xcodeproj

            mkdir -p "$stage/lib/release"
            cp "$stage/lib/libopenjp2.a" "$stage/lib/release/libopenjp2.a"

            mkdir -p "$stage/include/openjpeg"
            cp src/lib/openjp2/openjpeg.h "$stage/include/openjpeg"
            cp src/lib/openjp2/opj_stdint.h "$stage/include/openjpeg"
            cp src/lib/openjp2/opj_config.h "$stage/include/openjpeg"
            cp src/lib/openjp2/event.h "$stage/include/openjpeg"

        ;;
        linux64)
            rm -rf build
            mkdir build
            cd build
            cmake .. -DCMAKE_CXX_FLAGS="-m$AUTOBUILD_ADDRSIZE" -DCMAKE_C_FLAGS="-m$AUTOBUILD_ADDRSIZE" -DCMAKE_INSTALL_PREFIX=${stage} -DBUILD_CODEC=OFF -DBUILD_SHARED_LIBS=OFF

            make
            make install

            mv "$stage/lib/libopenjp2.a" "$stage"
            rm -rf "$stage/lib"
            mkdir -p "$stage/lib/release"
            mv "$stage/libopenjp2.a" "$stage/lib/release"

            mkdir -p "$stage/include/openjpeg"
			
            cp ../src/lib/openjp2/openjpeg.h "$stage/include/openjpeg"
            cp ../src/lib/openjp2/opj_stdint.h "$stage/include/openjpeg"
            cp src/lib/openjp2/opj_config.h "$stage/include/openjpeg"
            cp ../src/lib/openjp2/event.h "$stage/include/openjpeg"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE.txt "$stage/LICENSES/openjpeg.txt"
popd
