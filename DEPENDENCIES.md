# Vampyre Imaging Library (Panvyo fork) - Dependencies

This document lists all external dependencies for the library, organized by component.

## Core Library Dependencies

### LibJpeg-turbo (JPEG Support)

**Purpose**: High-performance JPEG encoding/decoding with SIMD acceleration.

**Binding**: `Source/JpegTurbo/libjpegturbo.pas`

| Platform | Library Name | Installation |
|----------|-------------|--------------|
| Windows x64 | `libjpeg-62.dll` or `turbojpeg.dll` | Download from [libjpeg-turbo releases](https://github.com/libjpeg-turbo/libjpeg-turbo/releases) |
| Linux x64 | `libjpeg.so.62` | `apt install libjpeg-turbo8` (Debian/Ubuntu) or `dnf install libjpeg-turbo` (Fedora) |
| macOS x64/ARM64 | `libjpeg.62.dylib` | `brew install jpeg-turbo` |

**Fallback**: If not available, falls back to FPC's built-in PasJpeg unit.

### zlib-ng (PNG/Compression Support)

**Purpose**: High-performance compression for PNG and other formats.

**Binding**: `Source/ZLib/zlibng_bindings.pas`

| Platform | Library Name | Installation |
|----------|-------------|--------------|
| Windows x64 | `zlib1.dll` (compat) or `zlib-ng2.dll` | Download from [zlib-ng releases](https://github.com/zlib-ng/zlib-ng/releases) |
| Linux x64 | `libz.so.1` (system) | `apt install zlib1g` (usually pre-installed) |
| macOS x64/ARM64 | `libz.1.dylib` (system) | Pre-installed on macOS |

**Fallback**: If not available, falls back to FPC's built-in PasZLib unit.

---

## Extension Dependencies

### LibTiff (TIFF Support)

**Units**: `Extensions/LibTiff/LibTiffDynLib.pas`, `Extensions/LibTiff/ImagingTiffLib.pas`

**Linking**: Dynamic only (static linking has been removed)

| Platform | Library Name | Installation |
|----------|-------------|--------------|
| Windows x64 | `libtiff.dll` | Download from [libtiff releases](http://www.libtiff.org/) |
| Linux x64 | `libtiff.so.5` | `apt install libtiff5` |
| macOS x64/ARM64 | `libtiff.5.dylib` | `brew install libtiff` |

**Note**: If the library is not found, TIFF format support is simply not registered. The library will still function for all other formats.

### OpenJPEG (JPEG2000 Support)

**Units**: `Extensions/ImagingJpeg2000.pas`, `Extensions/OpenJpegDynLib.pas`

**Linking**: Dynamic only (static linking has been removed)

| Platform | Library Name | Installation |
|----------|-------------|--------------|
| Windows x64 | `openjp2.dll` | Download from [OpenJPEG releases](https://github.com/uclouvain/openjpeg/releases) |
| Linux x64 | `libopenjp2.so.7` | `apt install libopenjp2-7` |
| macOS x64/ARM64 | `libopenjp2.7.dylib` | `brew install openjpeg` |

**Note**: If the library is not found, JPEG2000 format support is simply not registered. The library will still function for all other formats.

### OpenGL (Texture Support)

**Unit**: `Extensions/ImagingOpenGL.pas`

**Dependencies**:
- FPC's built-in `gl` and `glext` units, OR
- `dglOpenGL` header (define `OPENGL_USE_DGL_HEADERS`)

OpenGL drivers are typically pre-installed with graphics drivers.

### Graphics32 (GR32 Integration)

**Unit**: `Extensions/ImagingGraphics32.pas`

**Dependencies**: Graphics32 library (GR32)

Install via Lazarus Online Package Manager or from [graphics32.org](http://graphics32.org/).

### SDL (Surface Support)

**Unit**: `Extensions/ImagingSdl.pas`

**Dependencies**: SDL 1.2 or SDL 2.0

| Platform | Installation |
|----------|--------------|
| Windows | Download from [libsdl.org](https://www.libsdl.org/) |
| Linux | `apt install libsdl2-dev` |
| macOS | `brew install sdl2` |

### Squish (DXT Compression)

**Unit**: `Extras/Extensions/ImagingSquishLib.pas`

**Dependencies**: Squish library (dynamic linking)

Download or compile from [libsquish](https://github.com/Ethatron/squern).

---

## Build Tools

### Documentation Generator

**Tool**: `Extras/Tools/DracoolaDoc/`

No external dependencies. Pure Pascal implementation.

---

## Platform Support Summary

| Component | Windows x64 | Linux x64 | macOS x64 | macOS ARM64 |
|-----------|:-----------:|:---------:|:---------:|:-----------:|
| Core Library | Yes | Yes | Yes | Yes |
| JPEG (libjpeg-turbo) | Yes | Yes | Yes | Yes |
| PNG (zlib-ng) | Yes | Yes | Yes | Yes |
| TIFF | Yes | Yes | Yes | Yes |
| JPEG2000 | Yes | Yes | Yes | Yes |
| OpenGL | Yes | Yes | Yes | Yes |
| Graphics32 | Yes | Yes | Yes | Yes |
| SDL | Yes | Yes | Yes | Yes |

---

## Fallback Behavior

The library is designed to handle missing dependencies gracefully:

1. **JPEG**: Falls back to PasJpeg (slower, but functional)
2. **zlib**: Falls back to PasZLib (slower, but functional)
3. **TIFF**: Format not registered if library unavailable (no fallback)
4. **JPEG2000**: Format not registered if library unavailable (no fallback)

For core formats (JPEG, PNG), the library includes pure Pascal fallbacks ensuring it can be used in environments where installing system libraries is not possible. Extension formats (TIFF, JPEG2000) require their respective dynamic libraries to be available.
