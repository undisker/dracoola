#!/bin/bash

# LCL demos require Lazarus IDE with lazbuild.
# Some demos require additional packages:
#   - BGRAViewer requires BGRABitmapPack (install via Online Package Manager)

echo "Building LCL Demos using lazbuild (Lazarus)"
echo

ROOTDIR=".."
DEMOPATH="$ROOTDIR/Demos/ObjectPascal"

# Find lazbuild
LAZBUILD=""
if command -v lazbuild &> /dev/null; then
    LAZBUILD="lazbuild"
elif [ -x "/usr/bin/lazbuild" ]; then
    LAZBUILD="/usr/bin/lazbuild"
elif [ -x "/usr/local/bin/lazbuild" ]; then
    LAZBUILD="/usr/local/bin/lazbuild"
elif [ -x "/Applications/Lazarus/lazbuild" ]; then
    LAZBUILD="/Applications/Lazarus/lazbuild"
fi

if [ -z "$LAZBUILD" ]; then
    echo "ERROR: lazbuild not found. Please install Lazarus IDE."
    echo "Download from: https://www.lazarus-ide.org/"
    echo "  - Linux: Install via package manager (apt install lazarus, dnf install lazarus, etc.)"
    echo "  - macOS: Install from DMG or use Homebrew (brew install lazarus)"
    exit 1
fi

echo "Using lazbuild: $LAZBUILD"
echo

DEMOSBUILD=0
DEMOCOUNT=3

SWITCH="\033["
NORMAL="${SWITCH}0m"
RED="${SWITCH}0;31m"
GREEN="${SWITCH}0;32m"

function buildDemo {
    echo "Building $2..."
    if $LAZBUILD "$DEMOPATH/$1" > /dev/null 2>&1; then
        echo -e "  ${GREEN}[OK]${NORMAL} $2"
        ((DEMOSBUILD++))
    else
        echo -e "  ${RED}[FAILED]${NORMAL} $2 - trying with verbose output:"
        $LAZBUILD "$DEMOPATH/$1"
        echo
    fi
}

buildDemo "LCLImager/lclimager.lpi" "LCL Imager"
buildDemo "ImageBrowser/ImgBrowser.lpi" "Image Browser"
buildDemo "BGRAViewer/BGRAViewer.lpi" "BGRA Viewer"

echo
if [ $DEMOSBUILD = $DEMOCOUNT ]; then
    echo -e "${GREEN}Build Successful - all $DEMOSBUILD of $DEMOCOUNT LCL demos built in Demos/Bin directory${NORMAL}"
else
    echo -e "${RED}Errors during building - only $DEMOSBUILD of $DEMOCOUNT LCL demos built${NORMAL}"
    echo
    echo "Note: BGRAViewer requires BGRABitmapPack package."
    echo "Install it via: Tools > Online Package Manager > BGRABitmap"
    exit 1
fi
