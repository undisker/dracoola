Dracoola Imaging Library
===================================

![Imaging Logo](https://raw.githubusercontent.com/undisker/dracoola/refs/heads/master/Demos/Data/Logo.png)

High-performance fork of [Vampyre Imaging Library](https://github.com/galfar/imaginglib) with SIMD acceleration and multi-threading support.
*FreePascal-only!*

Overview
--------------------------

Dracoola Imaging Library is a performance-focused fork of the Vampyre Imaging Library, optimized exclusively for FreePascal. 
This fork removes introduces modern performance optimizations:

- **LibJpeg-turbo integration** - SIMD-accelerated JPEG encoding/decoding (2-6x faster than pure Pascal)
- **zlib-ng integration** - Optimized zlib replacement for faster PNG compression
- **SIMD pixel conversions** - SSE2/AVX2 on x64, NEON on ARM64
- **SIMD image resizing** - Hardware-accelerated bilinear/bicubic interpolation
- **Multi-threading support** - Parallel image processing with thread pool
- **Aligned memory allocation** - Optimized for SIMD operations

Requirements
--------------------------

- **Compiler**: FreePascal 3.2.0 or later (Delphi is *NOT* supported)
- **Platforms**: Windows x64, Linux x64, macOS (x64 and ARM64)
- **IDE**: Lazarus 2.0+ recommended
- **GUI**: LCL (Lazarus Component Library) for GUI components

Installation
--------------------------

### Lazarus Package Installation

1. Open Lazarus IDE
2. Go to **Package** → **Open Package File (.lpk)**
3. Navigate to `Packages/DracoolaImagingPackage.lpk`
4. Click **Compile**, then **Use** → **Install**
5. Restart Lazarus when prompted

For extensions (TIFF, JPEG2000, etc.), also install `Packages/DracoolaImagingPackageExt.lpk`.

External Libraries (Dynamic Linking)
--------------------------

For optimal performance, the following libraries should be available:

### Windows x64
- `libjpeg-62.dll` or `turbojpeg.dll` (from libjpeg-turbo)
- `zlib1.dll` (zlib-compat) or `zlib-ng2.dll`

### Linux x64
- `libjpeg.so.62` (from libjpeg-turbo) or system package
- `libz.so.1` (system) or `libz-ng.so.2`



Install via package Manager:


### Ubuntu/Debian
`apt install libjpeg-turbo8 zlib1g`


### Fedora/RHEL
`dnf install libjpeg-turbo zlib`


### macOS (x64 and ARM64)
- `libjpeg.62.dylib` (from libjpeg-turbo or Homebrew)
- System zlib (`libz.1.dylib`) is sufficient

Install via Homebrew:

`brew install jpeg-turbo`


If external libraries are not available, the library falls back to pure Pascal implementations.

Features
--------------------------

### Image File Formats

Loading and saving of these image file formats:

- PNG/APNG, MNG, JNG
- JPEG (via LibJpeg-turbo for maximum performance)
- GIF
- DDS, QOI, HDR
- TGA, BMP
- PCX, XPM, PNM/PPM, PSD
- TIFF, JPEG2000 (via Extensions package)
- and more

### Pixel Formats

Many internal image data formats and conversions:

- 8, 16, 24, 32, 48 and 64 bit RGB and ARGB formats
- Indexed formats
- Grayscale formats
- Floating point formats (IEEE754 and half precision)
- Compressed formats like DXT1/3/5, 3Dc, and BTC

### Performance Features

- **SIMD Conversions**: Hardware-accelerated pixel format conversions
  - RGB24 <-> RGBA32
  - RGBA <-> BGRA channel swapping
  - Grayscale conversions
  - Alpha premultiplication

- **SIMD Resizing**: Fast image scaling with:
  - Nearest neighbor (fastest)
  - Bilinear interpolation
  - Bicubic interpolation (Catmull-Rom)

- **Multi-threading**: Parallel processing for:
  - Large image operations
  - Tile-based processing
  - Configurable thread pool

### Basic Operations

- Image resizing (bilinear/bicubic)
- Rotation by any angle
- Color reduction
- Mipmap generation
- Image drawing with blending
- Linear and nonlinear filters
- Point transforms
- Binary morphology

Project Structure
--------------------------

```
Dracoola/
├── Source/                    # Core library source
│   ├── Imaging.pas           # Main unit
│   ├── ImagingTypes.pas      # Type definitions
│   ├── ImagingFormats.pas    # Pixel format handling
│   ├── ImagingMemory.pas     # Aligned memory allocation
│   ├── ImagingSimd.pas       # SIMD conversions
│   ├── ImagingSimdResize.pas # SIMD resizing
│   ├── ImagingThreadPool.pas # Thread pool
│   ├── JpegTurbo/            # LibJpeg-turbo bindings
│   └── ZLib/                 # zlib-ng bindings
├── Packages/                  # Lazarus packages
│   ├── DracoolaImagingPackage.lpk
│   └── DracoolaImagingPackageExt.lpk
├── Extensions/                # Optional format extensions
│   ├── ImagingTiff.pas       # TIFF base support
│   ├── ImagingJpeg2000.pas   # JPEG2000 support
│   ├── OpenJpegDynLib.pas    # OpenJPEG 2.x bindings
│   ├── ImagingOpenGL.pas     # OpenGL texture support
│   ├── ImagingGraphics32.pas # Graphics32 integration
│   ├── ImagingSdl.pas        # SDL surface support
│   └── LibTiff/              # LibTiff bindings (dynamic)
├── Extras/                    # Additional tools and packages
│   ├── Extensions/           # Extra extensions (SquishLib)
│   └── Packages/             # Optional legacy packages (GR32, SDL, OpenGL)
├── Demos/ObjectPascal/        # Demo applications
│   ├── LCLImager/            # LCL image viewer
│   ├── ImageBrowser/         # LCL image browser
│   ├── Benchmark/            # Performance benchmark
│   ├── DracoolaConvert/      # Command-line converter
│   ├── OpenGLDemo/           # OpenGL texture demo
│   └── SDLDemo/              # SDL surface demo
├── Scripts/                   # Build scripts (FPC cross-platform)
└── Doc/                       # Documentation
```

Extensions and Dependencies
--------------------------

### Core Extensions (Extensions/)

| Extension | External Dependency | Platforms |
|-----------|-------------------|-----------|
| `ImagingTiff.pas` | libtiff (dynamic only) | All |
| `ImagingJpeg2000.pas` | OpenJPEG (dynamic only) | All |
| `ImagingOpenGL.pas` | OpenGL (dglOpenGL or FPC gl units) | All |
| `ImagingGraphics32.pas` | Graphics32 library | All |
| `ImagingSdl.pas` | SDL 1.2 or SDL 2.0 | All |
| `ImagingPcx.pas` | None | All |
| `ImagingPsd.pas` | None | All |
| `ImagingXpm.pas` | None | All |

### LibTiff Support

TIFF support uses **dynamic linking** only (`LibTiffDynLib.pas`). Requires system `libtiff`:
  - Windows: `libtiff.dll`
  - Linux: `libtiff.so.5`
  - macOS: `libtiff.5.dylib`

Install via package manager:
- Ubuntu/Debian: `apt install libtiff5`
- Fedora/RHEL: `dnf install libtiff`
- macOS: `brew install libtiff`

### JPEG2000 Support

JPEG2000 support uses **dynamic linking** only (`OpenJpegDynLib.pas`). Requires system `openjpeg`:
  - Windows: `openjp2.dll`
  - Linux: `libopenjp2.so.7`
  - macOS: `libopenjp2.7.dylib`

Install via package manager:
- Ubuntu/Debian: `apt install libopenjp2-7`
- Fedora/RHEL: `dnf install openjpeg2`
- macOS: `brew install openjpeg`

### Extra Packages (Extras/Packages/)

| Package | Purpose | Dependency |
|---------|---------|------------|
| `DracoolaImagingPackage_OpenGL.lpk` | OpenGL texture support | OpenGL |
| `DracoolaImagingPackage_GR32.lpk` | Graphics32 integration | Graphics32 |
| `DracoolaImagingPackage_SDL.lpk` | SDL surface support | SDL |

Configuration
--------------------------

Edit `Source/ImagingOptions.inc` to configure:

```pascal
{ Memory allocation }
{$DEFINE USE_ALIGNED_ALLOC}           // Aligned memory for SIMD
{$DEFINE USE_PLATFORM_ALIGNED_ALLOC}  // Use OS-specific allocation

{ SIMD options }
{.$DEFINE USE_SIMD}                   // Enable SIMD optimizations
{.$DEFINE USE_SIMD_RESIZE}            // Enable SIMD resizing
{.$DEFINE USE_SIMD_CONVERT}           // Enable SIMD conversions

{ Multi-threading }
{.$DEFINE IMAGING_MULTITHREADED}      // Enable thread pool
```

New Units
--------------------------

| Unit | Description |
|------|-------------|
| `ImagingMemory.pas` | Aligned memory allocation for SIMD |
| `ImagingSimd.pas` | SIMD pixel format conversions |
| `ImagingSimdResize.pas` | SIMD image resizing |
| `ImagingThreadPool.pas` | Thread pool for parallel processing |
| `JpegTurbo/libjpegturbo.pas` | LibJpeg-turbo bindings |
| `ZLib/zlibng_bindings.pas` | zlib-ng bindings |

Quick Start
--------------------------

```pascal
program ImageExample;

uses
  Imaging, ImagingTypes, ImagingClasses;

var
  Img: TSingleImage;
begin
  Img := TSingleImage.Create;
  try
    // Load an image
    Img.LoadFromFile('input.jpg');

    // Resize to 800x600
    Img.Resize(800, 600, rfBicubic);

    // Convert to grayscale
    Img.ConvertToPixelFormat(ifGray8);

    // Save as PNG
    Img.SaveToFile('output.png');
  finally
    Img.Free;
  end;
end.
```

Migration from Vampyre Imaging Library
--------------------------

This fork is API-compatible with the original library for *most* use cases. Key differences:

1. **Delphi is not supported** - FPC Syntax and standard libraries are used. No support for VCL component, LCL support only.
2. **64-bit optimizations** - support for 32-bit platforms is not considered
3. **Dynamic linking** - External libraries used for JPEG/zlib by Default. Static linking for libtiff and openjpeg has been removed.
4. **New units** - Additional units for SIMD and threading


To migrate:
1. Ensure you're using FreePascal 3.2.0+ with Lazarus
2. Update package references from `VampyreImagingPackage` to `DracoolaImagingPackage`
3. Distribute required DLLs/SOs with your application (or rely on fallbacks, where avaialble)

License
------------------

This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. 
If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0.

Credits
------------------

- Original Vampyre Imaging Library by Marek Mauder
- Dracoola fork performance optimizations by Oleg Akopov

Based on Vampyre Imaging Library: <https://github.com/galfar/imaginglib>
