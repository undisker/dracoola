# Vampyre Imaging Library — Panvyo fork

![Imaging Logo](https://raw.githubusercontent.com/undisker/dracoola/refs/heads/master/Demos/Data/Logo.png)

**High-Performance Fork of [Vampyre Imaging Library](https://github.com/galfar/imaginglib) for FreePascal/Lazarus**

Version: 2025.01

---

## Table of Contents

1. [Introduction](#introduction)
   - [About](#about)
   - [Features](#features)
   - [License](#license)
2. [Getting Started](#getting-started)
   - [Supported Platforms](#supported-platforms)
   - [Installation](#installation)
   - [Dependencies](#dependencies)
3. [Using the Library](#using-the-library)
   - [Low Level Interface](#low-level-interface)
   - [High Level Interface](#high-level-interface)
   - [LCL Components](#lcl-components)
   - [Canvas Class](#canvas-class)
4. [Supported Data Formats](#supported-data-formats)
   - [ARGB Formats](#argb-formats)
   - [Indexed Formats](#indexed-formats)
   - [Grayscale Formats](#grayscale-formats)
   - [Floating-Point Formats](#floating-point-formats)
   - [Special Formats](#special-formats)
5. [Supported File Formats](#supported-file-formats)
   - [Core Formats](#core-formats)
   - [Extension Formats](#extension-formats)
6. [Extensions](#extensions)
   - [OpenGL Textures](#opengl-textures)
   - [Direct3D Textures](#direct3d-textures)
   - [SDL Surfaces](#sdl-surfaces)
7. [Performance Optimizations](#performance-optimizations)
   - [TurboJPEG Integration](#turbojpeg-integration)
   - [zlib-ng Integration](#zlib-ng-integration)
   - [SIMD Optimizations](#simd-optimizations)
   - [Multi-threading](#multi-threading)
8. [API Reference](#api-reference)
   - [General Functions](#general-functions)
   - [Loading Functions](#loading-functions)
   - [Saving Functions](#saving-functions)
   - [Manipulation Functions](#manipulation-functions)
   - [Drawing Functions](#drawing-functions)
   - [Palette Functions](#palette-functions)
   - [Options Functions](#options-functions)
9. [Code Examples](#code-examples)
10. [Building from Source](#building-from-source)
11. [Migration from Vampyre](#migration-from-vampyre)

---

## Introduction

### About

This is a FreePascal-only fork of the **Vampyre Imaging Library** by Marek Mauder, maintained for use in Panvyo. It swaps the bundled pure-Pascal codecs for their C counterparts (libjpeg-turbo, zlib-ng, dynamic OpenJPEG and LibTiff). The API, unit names and pixel layout are upstream's, unchanged.

Motivation was faster decoding of the formats a file viewer opens most, without changing the API.

> **Note:** earlier revisions of this document described SIMD acceleration and
> multi-threading as features. Those units were never wired into any call path
> and were removed on 2026-08-24. See `readme.md`.

Key improvements over the original Vampyre library:
- **FreePascal-only**: Removed all Delphi-specific code for cleaner codebase
- **TurboJPEG API**: Native libjpeg-turbo integration for SIMD-accelerated JPEG processing
- **zlib-ng**: High-performance zlib replacement for faster PNG/compression operations
- **SIMD pixel conversions**: SSE2/AVX2 on x64, NEON on ARM64
- **BGRABitmap**: Demos are based on modern BGRA package instead of own components

### Features

- **Native Object Pascal** open-source cross-platform library
- **Supported platforms**:
  - Windows x64
  - Linux x64
  - macOS (Intel and Apple Silicon ARM64)

- **Image file formats** (loading and saving):
  - **JPEG** (via TurboJPEG - SIMD accelerated)
  - **PNG/APNG** (via zlib-ng - high performance)
  - **BMP**, **GIF**, **TGA**, **DDS**
  - **MNG**, **JNG**
  - **PBM**, **PGM**, **PPM**, **PAM**, **PFM**
  - **TIFF**, **PSD**, **PCX**, **XPM**
  - **JPEG2000**, **QOI**

- **Internal image data formats**:
  - 8, 16, 24, 32, 48, and 64-bit RGB/ARGB formats
  - Indexed formats (up to 256 colors)
  - Grayscale formats (8, 16, 32, 64-bit)
  - Floating-point formats (IEEE-754 and half-precision)
  - Compressed formats: DXT1/3/5, 3Dc, BTC

- **Image manipulation**:
  - Bilinear/bicubic resizing
  - Mipmap generation
  - Color reduction and quantization
  - Format conversion between all supported formats
  - Rotation, flipping, mirroring

- **Extensions (legacy)**:
  - OpenGL texture creation
  - Direct3D texture creation
  - SDL surface support
  - LCL graphic classes and components

### License & Credits

This is a fork of the **Vampyre Imaging Library** by Marek Mauder, and it is
licensed exactly as upstream is: **Mozilla Public License 2.0 (MPL-2.0)**, and
nothing else.

An earlier version of this document claimed the library was "available under
dual licensing" with the LGPL and that you "may choose whichever license fits
your needs best". **That was wrong and has been removed.** Upstream Vampyre has
only ever been MPL-2.0; a fork cannot offer someone else's code under a licence
its copyright holder never granted. If you obtained this library relying on
that statement, the licence that actually applies is MPL-2.0.

MPL-2.0 is file-level copyleft: modified MPL files must be made available in
source form, which they are — this repository is public. Code you write in
separate files is not affected.

Original library by Marek Mauder (<https://github.com/galfar/imaginglib>).
This fork is maintained by Oleg Akopov for use in Panvyo.

---

## Getting Started

### Supported Platforms

| Platform | Architecture | Status |
|----------|--------------|--------|
| Windows | x64 | Fully supported |
| Linux | x64 | Fully supported |
| macOS | x64 (Intel) | Supported |
| macOS | ARM64 (Apple Silicon) | Supported |

**Note on macOS support status**: macOS platforms are marked as "Supported" rather than "Fully Supported" due to the following considerations:

- **SIMD optimizations**: Full SIMD coverage is implemented for both pixel format conversions and image resizing on all platforms. Intel Macs use SSE2, Apple Silicon uses NEON - both achieve feature parity with Windows/Linux builds.
- **Testing coverage**: Windows and Linux receive more extensive testing due to CI infrastructure availability. macOS testing relies on manual verification.
- **External library availability**: TurboJPEG and zlib-ng may require Homebrew installation on macOS, whereas Linux distributions typically include these in standard repositories.

All core functionality works correctly on macOS, with SIMD-accelerated performance matching other platforms. The "Supported" designation reflects the reduced testing coverage rather than any functional or performance limitations.

### Installation

1. Extract the library archive to your preferred location
2. Add the following directories to your compiler's search path:

| Directory | Contents |
|-----------|----------|
| `Source` | Core library source code |
| `Source/ZLib` | zlib-ng bindings |
| `Source/JpegTurbo` | TurboJPEG bindings |
| `Extensions` | Additional file formats and features |
| `Extensions/LibTiff` | TIFF support |

#### FreePascal Setup

Add to your `fpc.cfg` or use command-line parameters:

```
-Fu(Imaging_Root)/Source
-Fu(Imaging_Root)/Source/ZLib
-Fu(Imaging_Root)/Source/JpegTurbo
-Fu(Imaging_Root)/Extensions
-Fi(Imaging_Root)/Source
```

#### Lazarus Setup

Add the source directories to your project's search paths in Project Options.

### Dependencies

this fork requires the following external libraries at runtime:

#### Core Libraries (Required)

| Library | Windows | Linux | macOS |
|---------|---------|-------|-------|
| TurboJPEG | `turbojpeg.dll` | `libturbojpeg.so.0` | `libturbojpeg.0.dylib` |
| zlib-ng | `zlib-ng2.dll` | `libz-ng.so.2` | `libz-ng.2.dylib` |

#### Extension Libraries (Optional)

| Library | Windows | Linux | macOS | Purpose |
|---------|---------|-------|-------|---------|
| LibTIFF | `libtiff.dll` | `libtiff.so.5` | `libtiff.5.dylib` | TIFF support |
| OpenJPEG | `openjp2.dll` | `libopenjp2.so.7` | `libopenjp2.7.dylib` | JPEG2000 support |

On Linux and macOS, system packages can often be used:
- Ubuntu/Debian: `apt install libjpeg-turbo8 libtiff5 libopenjp2-7`
- Fedora/RHEL: `dnf install libjpeg-turbo libtiff openjpeg2`
- macOS: `brew install jpeg-turbo libtiff openjpeg`

**Note**: Extension libraries are optional. If not found, the corresponding file format support is simply not registered - the library will still function for all other formats.

---

## Using the Library

### Low Level Interface

The low-level interface operates on `TImageData` structures and `TDynImageDataArray`. These functions are implemented in `Imaging.pas`.

#### Basic Usage

```pascal
uses
  SysUtils, ImagingTypes, Imaging;

var
  Img: TImageData;
begin
  // Initialize image structure before use
  InitImage(Img);

  // Load image from file
  LoadImageFromFile('photo.jpg', Img);

  // Access image properties
  WriteLn('Width: ', Img.Width);
  WriteLn('Height: ', Img.Height);
  WriteLn('Format: ', GetFormatName(Img.Format));

  // Free image memory
  FreeImage(Img);
end.
```

#### Working with Multiple Images

```pascal
var
  Images: TDynImageDataArray;
  I: Integer;
begin
  // Load all frames from animated GIF or multi-page TIFF
  LoadMultiImageFromFile('animation.gif', Images);

  WriteLn('Loaded ', Length(Images), ' frames');

  for I := 0 to High(Images) do
    WriteLn('Frame ', I, ': ', Images[I].Width, 'x', Images[I].Height);

  // Free all images
  FreeImagesInArray(Images);
end.
```

### High Level Interface

The high-level interface provides object-oriented access through `TSingleImage` and `TMultiImage` classes in `ImagingClasses.pas`.

```pascal
uses
  ImagingClasses;

var
  Image: TSingleImage;
begin
  Image := TSingleImage.Create;
  try
    Image.LoadFromFile('photo.jpg');

    // Resize to 50%
    Image.Resize(Image.Width div 2, Image.Height div 2, rfBicubic);

    // Convert format
    Image.Format := ifA8R8G8B8;

    Image.SaveToFile('photo_resized.png');
  finally
    Image.Free;
  end;
end.
```

### LCL Components

For Lazarus applications, use `ImagingComponents.pas` for LCL integration:

```pascal
uses
  ImagingComponents;

// Convert TImageData to LCL TBitmap
procedure DisplayImage(const Img: TImageData; Bitmap: TBitmap);
begin
  ConvertImageDataToBitmap(Img, Bitmap);
end;
```

### Canvas Class

`TImagingCanvas` in `ImagingCanvases.pas` provides drawing operations:

```pascal
uses
  ImagingCanvases;

var
  Canvas: TImagingCanvas;
  Img: TImageData;
begin
  NewImage(640, 480, ifA8R8G8B8, Img);
  Canvas := TImagingCanvas.CreateForData(@Img);
  try
    Canvas.FillColor32 := $FF0000FF; // Blue
    Canvas.FillRect(10, 10, 100, 100);

    Canvas.PenColor32 := $FFFF0000; // Red
    Canvas.Line(0, 0, 639, 479);

    Canvas.Ellipse(200, 200, 300, 300);
  finally
    Canvas.Free;
    SaveImageToFile('drawing.png', Img);
    FreeImage(Img);
  end;
end.
```

---

## Supported Data Formats

Image data format is the internal memory representation of every image, described by `TImageFormat` enumeration.

### Format Naming Convention

Format names follow the pattern: `if[Channel][Size]...`

- `A` = Alpha channel
- `R` = Red channel
- `G` = Green channel
- `B` = Blue channel
- `X` = Unused bits
- `F` = Floating-point
- `Gray` = Grayscale intensity
- `Index` = Palette index

Example: `ifA8R8G8B8` = 32-bit with 8 bits each for Alpha, Red, Green, Blue

### ARGB Formats

| Format | Bits | Description |
|--------|------|-------------|
| `ifR3G3B2` | 8 | 3-3-2 bit RGB |
| `ifR5G6B5` | 16 | 5-6-5 bit RGB |
| `ifA1R5G5B5` | 16 | 1-bit alpha, 5-5-5 RGB |
| `ifA4R4G4B4` | 16 | 4-bit per channel |
| `ifR8G8B8` | 24 | 8-bit per channel RGB |
| `ifA8R8G8B8` | 32 | 8-bit per channel ARGB |
| `ifR16G16B16` | 48 | 16-bit per channel RGB |
| `ifA16R16G16B16` | 64 | 16-bit per channel ARGB |

### Indexed Formats

| Format | Description |
|--------|-------------|
| `ifIndex8` | 8-bit palette index (256 colors) |

### Grayscale Formats

| Format | Bits | Description |
|--------|------|-------------|
| `ifGray8` | 8 | 8-bit grayscale |
| `ifA8Gray8` | 16 | 8-bit gray + 8-bit alpha |
| `ifGray16` | 16 | 16-bit grayscale |
| `ifGray32` | 32 | 32-bit grayscale |
| `ifGray64` | 64 | 64-bit grayscale |
| `ifA16Gray16` | 32 | 16-bit gray + 16-bit alpha |

### Floating-Point Formats

| Format | Bits | Description |
|--------|------|-------------|
| `ifR32F` | 32 | Single-precision red channel |
| `ifA32R32G32B32F` | 128 | Single-precision ARGB |
| `ifR16F` | 16 | Half-precision red channel |
| `ifA16R16G16B16F` | 64 | Half-precision ARGB |

### Special Formats

| Format | Description |
|--------|-------------|
| `ifDXT1` | DXT1 compression (15/16-bit color, 1-bit alpha) |
| `ifDXT3` | DXT3 compression (16-bit color, 4-bit alpha) |
| `ifDXT5` | DXT5 compression (16-bit color, 8-bit alpha) |
| `ifBTC` | Block truncation coding (grayscale, 2 bpp) |
| `ifATI1N` | 3Dc+ compression (1 channel, 4 bpp) |
| `ifATI2N` | 3Dc compression (2 channels, 8 bpp) |

---

## Supported File Formats

### Core Formats

#### JPEG

JPEG support uses **TurboJPEG** for SIMD-accelerated encoding/decoding.

| Format | TImageFormat | Load | Save |
|--------|--------------|------|------|
| 24-bit RGB | `ifR8G8B8` | Yes | Yes |
| 8-bit grayscale | `ifGray8` | Yes | Yes |

**Options:**

| Option | Values | Description |
|--------|--------|-------------|
| `ImagingJpegQuality` | 1-100 | Compression quality (default: 90) |
| `ImagingJpegProgressive` | 0/1 | Progressive encoding (default: 0) |

#### PNG

PNG support includes **APNG** (animated PNG) with zlib-ng compression.

| Format | TImageFormat | Load | Save |
|--------|--------------|------|------|
| 1/2/4/8-bit indexed | `ifIndex8` | Yes | 8-bit only |
| 24-bit RGB | `ifR8G8B8` | Yes | Yes |
| 48-bit RGB | `ifR16G16B16` | Yes | Yes |
| 32-bit ARGB | `ifA8R8G8B8` | Yes | Yes |
| 64-bit ARGB | `ifA16R16G16B16` | Yes | Yes |
| Grayscale (1-16 bit) | `ifGray8/16` | Yes | 8/16-bit |
| Grayscale + Alpha | `ifA8Gray8/A16Gray16` | Yes | Yes |

**Options:**

| Option | Values | Description |
|--------|--------|-------------|
| `ImagingPNGPreFilter` | 0-6 | Pre-compression filter |
| `ImagingPNGCompressLevel` | 0-9 | Compression level (default: 5) |
| `ImagingPNGLoadAnimated` | 0/1 | Animate APNG frames (default: 1) |

#### BMP (Windows Bitmap)

Full support for Windows bitmap files including:
- 1, 4, 8, 16, 24, 32-bit formats
- RLE compression (loading)
- OS/2 bitmap variants

#### GIF

- 1-8 bit indexed images
- Animation support (load/save multiple frames)
- Transparency support

#### TGA (Targa)

- 8-bit indexed, 15/16/24/32-bit RGB/ARGB
- RLE compression support
- Origin specification (top-left/bottom-left)

#### DDS (DirectDraw Surface)

- DXT1/3/5 compressed textures
- Cubemaps and volume textures
- Mipmaps
- Various uncompressed formats

#### MNG/JNG

- MNG: Multiple Network Graphics (animated)
- JNG: JPEG Network Graphics (JPEG with alpha channel)

#### Portable Maps (PBM/PGM/PPM/PAM/PFM)

- Binary and ASCII formats
- Floating-point PFM support

### Extension Formats

#### JPEG2000

JPEG2000 support uses **OpenJPEG 2.x** via dynamic library loading. Supports:
- 8/16-bit grayscale and RGB
- Alpha channel support
- Lossless and lossy compression
- JP2 and J2K codestream formats

**Required Libraries:**

| Platform | Library |
|----------|---------|
| Windows x64 | `openjp2.dll` |
| Linux x64 | `libopenjp2.so.7` |
| macOS x64/ARM64 | `libopenjp2.7.dylib` |

On Linux: `apt install libopenjp2-7` (Debian/Ubuntu)
On macOS: `brew install openjpeg`

#### TIFF

TIFF support uses **LibTIFF 4.x** via dynamic library loading. Supports:
- Multiple pages
- Various compression methods (LZW, ZIP, JPEG, CCITT Fax)
- Wide range of bit depths (1-64 bit)
- EXIF metadata

**Required Libraries:**

| Platform | Library |
|----------|---------|
| Windows x64 | `libtiff.dll` |
| Linux x64 | `libtiff.so.5` |
| macOS x64/ARM64 | `libtiff.5.dylib` |

On Linux: `apt install libtiff5` (Debian/Ubuntu)
On macOS: `brew install libtiff`

#### PSD (Photoshop)

- Layers (flattened on load)
- Multiple color modes
- 8/16-bit channels

#### PCX (ZSoft PaintBrush)

Loading only:
- 1//4/8/24-bit formats
- RLE compression

#### XPM (X Pixmap)

- ASCII-based format
- Transparency support

---

## Extensions

### OpenGL Textures

`ImagingOpenGL.pas` provides functions to create OpenGL textures from images:

```pascal
uses
  ImagingOpenGL;

var
  TexID: GLuint;
begin
  TexID := CreateGLTextureFromFile('texture.png');
  // Use texture...
  glDeleteTextures(1, @TexID);
end;
```

### Direct3D Textures

`ImagingDirect3D9.pas` provides Direct3D 9 texture creation:

```pascal
uses
  ImagingDirect3D9;

var
  Texture: IDirect3DTexture9;
begin
  CreateD3DTextureFromFile(Device, 'texture.dds', Texture);
  // Use texture...
end;
```

### SDL Surfaces

`ImagingSDL.pas` provides SDL surface creation:

```pascal
uses
  ImagingSDL;

var
  Surface: PSDL_Surface;
begin
  Surface := LoadSDLSurfaceFromFile('image.png');
  // Use surface...
  SDL_FreeSurface(Surface);
end;
```

---

## Performance Optimizations

### TurboJPEG Integration

this fork uses the native **TurboJPEG API** (tj3* functions) from libjpeg-turbo for JPEG processing instead of obsolete libjpeg API:

- **SIMD acceleration**: Uses SSE2/AVX2 on x64, NEON on ARM64
- **Simple API**: No complex C struct alignment issues
- **Thread-safe**: Each handle is independent
- **Better error handling**: Descriptive error messages

The TurboJPEG implementation is in `Source/JpegTurbo/turbojpegapi.pas`.

### zlib-ng Integration

PNG and other compressed formats use **zlib-ng** for faster compression:

- Drop-in zlib replacement with modern optimizations
- SIMD-accelerated compression/decompression
- Better performance on modern CPUs

### SIMD Optimizations

Pixel format conversions and image resizing use SIMD instructions for maximum performance:

```pascal
// ImagingOptions.inc
{$DEFINE USE_SIMD_CONVERSIONS}  // Enable SIMD pixel conversions
```

**Platform Support:**

| Platform | Instruction Set | Status |
|----------|-----------------|--------|
| Windows x64 | SSE2 | Full coverage |
| Linux x64 | SSE2 | Full coverage |
| macOS Intel | SSE2 | Full coverage |
| macOS Apple Silicon | NEON | Full coverage |

**Optimized Pixel Conversions:**

| Operation | SSE2 (x64) | NEON (ARM64) |
|-----------|------------|--------------|
| RGBA32 <-> BGRA32 swap | Yes | Yes |
| RGB24 -> RGBA32 | Yes | Yes |
| RGBA32 -> RGB24 | Yes | Yes |
| Gray8 -> RGBA32 | Yes | Yes |
| RGBA32 -> Gray8 | Yes | Yes |
| RGB24 -> Gray8 | Yes | Yes |
| RGB24 <-> BGR24 swap | Yes | Yes |
| Set Alpha (RGBA32) | Yes | Yes |
| Fill Memory 32-bit | Yes | Yes |

**Optimized Image Resizing:**

| Operation | SSE2 (x64) | NEON (ARM64) |
|-----------|------------|--------------|
| Bilinear RGBA32 | Yes | Yes |
| Bicubic RGBA32 | Yes | Yes |
| Bilinear RGB24 | Yes | Yes |
| Bicubic RGB24 | Yes | Yes |
| Bilinear Gray8 | Yes | Yes |
| Bicubic Gray8 | Yes | Yes |

All SIMD implementations include scalar fallbacks for non-SIMD capable CPUs. The resize operations use fixed-point arithmetic for precision while maintaining performance.

### Multi-threading

Large image operations can be parallelized:

```pascal
// ImagingOptions.inc
{$DEFINE IMAGING_MULTITHREADED}  // Enable multi-threading
```

The thread pool is managed in `ImagingThreadPool.pas`:

```pascal
uses
  ImagingThreadPool;

// Operations automatically use parallel processing when beneficial
// Minimum 65536 pixels (256x256) before parallelization kicks in
```

---

## API Reference

### General Functions

| Function | Description |
|----------|-------------|
| `InitImage(var Img: TImageData)` | Initialize image structure |
| `NewImage(Width, Height: Integer; Format: TImageFormat; var Img: TImageData)` | Create new image |
| `TestImage(const Img: TImageData): Boolean` | Check if image is valid |
| `FreeImage(var Img: TImageData)` | Free image memory |
| `FreeImagesInArray(var Images: TDynImageDataArray)` | Free all images in array |
| `CloneImage(const Src: TImageData; var Dst: TImageData)` | Create copy of image |

### Loading Functions

| Function | Description |
|----------|-------------|
| `LoadImageFromFile(FileName: string; var Img: TImageData): Boolean` | Load from file |
| `LoadImageFromStream(Stream: TStream; var Img: TImageData): Boolean` | Load from stream |
| `LoadImageFromMemory(Data: Pointer; Size: Integer; var Img: TImageData): Boolean` | Load from memory |
| `LoadMultiImageFromFile(FileName: string; var Images: TDynImageDataArray): Boolean` | Load multiple images |
| `DetermineFileFormat(FileName: string): string` | Get format from file |
| `DetermineStreamFormat(Stream: TStream): string` | Get format from stream |

### Saving Functions

| Function | Description |
|----------|-------------|
| `SaveImageToFile(FileName: string; const Img: TImageData): Boolean` | Save to file |
| `SaveImageToStream(Ext: string; Stream: TStream; const Img: TImageData): Boolean` | Save to stream |
| `SaveImageToMemory(Ext: string; Data: Pointer; var Size: Integer; const Img: TImageData): Boolean` | Save to memory |
| `SaveMultiImageToFile(FileName: string; const Images: TDynImageDataArray): Boolean` | Save multiple images |

### Manipulation Functions

| Function | Description |
|----------|-------------|
| `ConvertImage(var Img: TImageData; DestFormat: TImageFormat): Boolean` | Convert format |
| `ResizeImage(var Img: TImageData; NewWidth, NewHeight: Integer; Filter: TResizeFilter): Boolean` | Resize image |
| `FlipImage(var Img: TImageData): Boolean` | Flip vertically |
| `MirrorImage(var Img: TImageData): Boolean` | Mirror horizontally |
| `RotateImage(var Img: TImageData; Angle: Single): Boolean` | Rotate by angle |
| `SwapChannels(var Img: TImageData; SrcChannel, DstChannel: Integer): Boolean` | Swap color channels |
| `ReduceColors(var Img: TImageData; MaxColors: Integer): Boolean` | Reduce color count |
| `GenerateMipMaps(const Img: TImageData; Levels: Integer; var MipMaps: TDynImageDataArray): Boolean` | Generate mipmaps |

### Drawing Functions

| Function | Description |
|----------|-------------|
| `CopyRect(const Src: TImageData; SrcX, SrcY, Width, Height: Integer; var Dst: TImageData; DstX, DstY: Integer): Boolean` | Copy rectangle |
| `FillRect(var Img: TImageData; X, Y, Width, Height: Integer; Color: Pointer): Boolean` | Fill rectangle |
| `StretchRect(const Src: TImageData; SrcX, SrcY, SrcWidth, SrcHeight: Integer; var Dst: TImageData; DstX, DstY, DstWidth, DstHeight: Integer; Filter: TResizeFilter): Boolean` | Stretch copy |
| `GetPixel32(const Img: TImageData; X, Y: Integer): TColor32` | Get pixel as 32-bit |
| `SetPixel32(var Img: TImageData; X, Y: Integer; Color: TColor32)` | Set pixel from 32-bit |

### Palette Functions

| Function | Description |
|----------|-------------|
| `NewPalette(Entries: Integer; var Palette: PPalette32): Boolean` | Create new palette |
| `FreePalette(var Palette: PPalette32): Boolean` | Free palette memory |
| `CopyPalette(Src, Dst: PPalette32; SrcIdx, DstIdx, Count: Integer): Boolean` | Copy palette entries |
| `FillGrayscalePalette(Palette: PPalette32; Entries: Integer): Boolean` | Fill with grayscale |
| `FindColor(Palette: PPalette32; Entries: Integer; Color: TColor32): Integer` | Find color index |

### Options Functions

| Function | Description |
|----------|-------------|
| `SetOption(OptionId, Value: Integer): Boolean` | Set option value |
| `GetOption(OptionId: Integer): Integer` | Get option value |
| `PushOptions: Boolean` | Save current options |
| `PopOptions: Boolean` | Restore saved options |

---

## Code Examples

### Load, Process, and Save

```pascal
uses
  SysUtils, ImagingTypes, Imaging;

procedure ProcessImage(const InputFile, OutputFile: string);
var
  Img: TImageData;
begin
  InitImage(Img);
  try
    // Load image
    if not LoadImageFromFile(InputFile, Img) then
      raise Exception.Create('Failed to load: ' + InputFile);

    // Convert to 32-bit ARGB for processing
    ConvertImage(Img, ifA8R8G8B8);

    // Resize to 800x600
    ResizeImage(Img, 800, 600, rfBicubic);

    // Set JPEG quality
    SetOption(ImagingJpegQuality, 85);

    // Save as JPEG
    if not SaveImageToFile(OutputFile, Img) then
      raise Exception.Create('Failed to save: ' + OutputFile);

  finally
    FreeImage(Img);
  end;
end;
```

### Create Thumbnail

```pascal
function CreateThumbnail(const FileName: string; MaxSize: Integer): TImageData;
var
  Scale: Single;
begin
  InitImage(Result);
  LoadImageFromFile(FileName, Result);

  // Calculate scale to fit within MaxSize
  if Result.Width > Result.Height then
    Scale := MaxSize / Result.Width
  else
    Scale := MaxSize / Result.Height;

  if Scale < 1.0 then
    ResizeImage(Result, Round(Result.Width * Scale),
                Round(Result.Height * Scale), rfLanczos);
end;
```

### Batch Convert Directory

```pascal
uses
  SysUtils, ImagingTypes, Imaging;

procedure ConvertDirectory(const SrcDir, DstDir, DstExt: string);
var
  SR: TSearchRec;
  Img: TImageData;
  SrcFile, DstFile: string;
begin
  ForceDirectories(DstDir);

  if FindFirst(SrcDir + PathDelim + '*.*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        SrcFile := SrcDir + PathDelim + SR.Name;

        // Check if it's a supported image
        if DetermineFileFormat(SrcFile) <> '' then
        begin
          InitImage(Img);
          try
            if LoadImageFromFile(SrcFile, Img) then
            begin
              DstFile := DstDir + PathDelim +
                         ChangeFileExt(SR.Name, '.' + DstExt);
              SaveImageToFile(DstFile, Img);
              WriteLn('Converted: ', SR.Name);
            end;
          finally
            FreeImage(Img);
          end;
        end;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;
```

---

## Building from Source

### Prerequisites

- FreePascal Compiler 3.2.0 or later
- Lazarus 2.0+ (for LCL components and demos)
- CMake 3.16+ (for building dependencies)

### Building Dependencies

#### libjpeg-turbo (TurboJPEG)

```bash
cd dependencies/libjpeg-turbo
mkdir build-win64 && cd build-win64
cmake .. -G "Visual Studio 17 2022" -A x64 -DWITH_TURBOJPEG=ON
cmake --build . --config Release
```

#### zlib-ng

```bash
cd dependencies/zlib-ng
mkdir build && cd build
cmake .. -DZLIB_COMPAT=ON
cmake --build . --config Release
```

### Building Demos

Using Lazarus:
```bash
cd Demos/ObjectPascal/LCLImager
lazbuild --build-mode=Release lclimager.lpi
```

Using command line:
```bash
cd Scripts
./BuildDemosFPC.sh  # Linux/macOS
BuildDemosFPC.bat   # Windows
```

---

## Migration from Vampyre

If you're migrating from the original Vampyre Imaging Library:

### Key Changes

1. **FreePascal only**: Remove any Delphi-specific code or conditionals
2. **No bundled JpegLib**: Uses external TurboJPEG library
3. **No bundled ZLib**: Uses external zlib-ng library
4. **LCL only**: VCL support removed; use LCL for GUI components

### Unit Changes

| Old Unit | New Unit |
|----------|----------|
| `imjpeglib` | `turbojpegapi` |
| `impaszlib` | `zlibng_bindings` |

### Required DLLs

Copy these to your application directory:
- `turbojpeg.dll` (Windows)
- `zlib-ng2.dll` (Windows)

Or install system packages on Linux/macOS.

### Version Format

Version changed from `0.xx.x` to `YYYY.MM`:
- Old: `0.26.4`
- New: `2026.01`

---

## Credits

### this fork

- High-performance FreePascal-only fork by Oleg Akopov
- TurboJPEG and zlib-ng integration
- SIMD and multi-threading optimizations


### Original Vampyre Imaging Library

- **Author**: Marek Mauder
- **Website**: https://github.com/galfar/imaginglib
- **Documentation**: https://imaginglib.sourceforge.io

### Third-Party Libraries

- **libjpeg-turbo**: SIMD-accelerated JPEG codec (via TurboJPEG API)
- **zlib-ng**: High-performance zlib replacement
- **LibTIFF 4.x**: TIFF format support (dynamic library)
- **OpenJPEG 2.x**: JPEG2000 support (dynamic library)

---

*This documentation is for this fork version 2025.01*
