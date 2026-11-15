#!/bin/bash
# Builds both the rootless (iphoneos-arm64) and rootful (iphoneos-arm) packages.
#
# On this Linux VM the build runs on a copy under /tmp: ldid cannot sign
# in place on the workspace filesystem, and dpkg-deb rejects the staging
# permissions produced with the default umask there. On macOS (see
# .github/workflows) a plain `make package` in the repo works as usual.
set -e
cd "$(dirname "$0")"
SRC="$PWD"

export THEOS="${THEOS:-$HOME/workspace/theos}"
export PATH="$HOME/workspace/bin:$PATH"
export COMPILER_PATH="$HOME/workspace/bin"

BUILD=/tmp/lilliftboard-build
rm -rf "$BUILD"
mkdir -p "$BUILD"
cp -r . "$BUILD/"
cd "$BUILD"
rm -rf .theos packages research
chmod -R u=rwX,go=rX .
umask 022

make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
make clean
make package FINALPACKAGE=1

mkdir -p "$SRC/packages"
cp packages/*.deb "$SRC/packages/"
ls -lh "$SRC/packages/"
