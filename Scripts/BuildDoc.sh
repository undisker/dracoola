#!/bin/bash

# Dracoola Imaging Library - Documentation Build Script
# Cross-platform (Linux/macOS)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "Building XHTML documentation"
./Bin/DracoolaDoc -doc -f=xhtml -i=./Doc/DracoolaDoc/Imaging.vdocproj -o=./Doc

echo "Building HTMLHelp documentation"
./Bin/DracoolaDoc -doc -f=htmlhelp -i=./Doc/DracoolaDoc/Imaging.vdocproj -o=./Doc

echo "Done."
