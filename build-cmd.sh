#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

OPENJPEG_VERSION="2.1"
OPENJPEG_SOURCE_DIR="src"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)/stage"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${OPENJPEG_VERSION}.${build}" > "${stage}/VERSION.txt"

pushd "$OPENJPEG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "windows")
			echo "Not tested"
			exit 1
            load_vsvars

			if [ "${ND_AUTOBUILD_ARCH}" == "x64" ]
			then
				cmake . -G"Visual Studio 12 Win64" -DCMAKE_INSTALL_PREFIX=$stage -DND_WIN64_BUILD=On

				build_sln "OPENJPEG.sln" "Release|x64"
				build_sln "OPENJPEG.sln" "Debug|x64"
			else
				cmake . -G"Visual Studio 12" -DCMAKE_INSTALL_PREFIX=$stage

				build_sln "OPENJPEG.sln" "Release|Win32"
				build_sln "OPENJPEG.sln" "Debug|Win32"
			fi

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp bin/Release/openjpeg{.dll,.lib} "$stage/lib/release"
            cp bin/Debug/openjpeg.dll "$stage/lib/debug/openjpegd.dll"
            cp bin/Debug/openjpeg.lib "$stage/lib/debug/openjpegd.lib"
            cp bin/Debug/openjpeg.pdb "$stage/lib/debug/openjpegd.pdb"
            mkdir -p "$stage/include/openjpeg"
            cp libopenjpeg/openjpeg.h "$stage/include/openjpeg"
        ;;
        "darwin")
			echo "Not tested"
			exit 1
	    cmake . -GXcode -D'CMAKE_OSX_ARCHITECTURES:STRING=i386;x86_64' \
	    	-D'BUILD_SHARED_LIBS:bool=off' -D'BUILD_CODEC:bool=off' \
	    	-DCMAKE_INSTALL_PREFIX=$stage -DCMAKE_OSX_DEPLOYMENT_TARGET=10.7 \
	    	-DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk
	    xcodebuild -configuration Release -target openjpeg -project openjpeg.xcodeproj
	    xcodebuild -configuration Release -target install -project openjpeg.xcodeproj
            mkdir -p "$stage/lib/release"
	    cp "$stage/lib/libopenjpeg.a" "$stage/lib/release/libopenjpeg.a"
            mkdir -p "$stage/include/openjpeg"
	    cp "$stage/include/openjpeg-$OPENJPEG_VERSION/openjpeg.h" "$stage/include/openjpeg"
	  
        ;;
        "linux")

			rm -rf build
            mkdir build
            cd build
            cmake .. -DCMAKE_CXX_FLAGS=-"${ND_AUTOBUILD_GCC_ARCH_FLAG}" -DCMAKE_C_FLAGS="${ND_AUTOBUILD_GCC_ARCH_FLAG}" -DCMAKE_INSTALL_PREFIX=${stage} -DBUILD_CODEC=OFF -DBUILD_SHARED_LIBS=OFF

            make
			make install

			rm -rf "$stage/include/openjpeg-$OPENJPEG_VERSION-fs"
            mv "$stage/include/openjpeg-$OPENJPEG_VERSION/" "$stage/include/openjpeg-$OPENJPEG_VERSION-fs"

            mv "$stage/lib/libopenjp2.a" "$stage"
			rm -rf "$stage/lib"
            mkdir -p "$stage/lib/release"
            mv "$stage/libopenjp2.a" "$stage/lib/release"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE.txt "$stage/LICENSES/openjpeg.txt"
popd

pass
