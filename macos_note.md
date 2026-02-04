# macOS Library Build Instructions

The `libs/macos-arm64/` and `libs/macos-x64/` folders are currently empty because macOS library builds require a macOS environment.

## Building on macOS

### Prerequisites
- Xcode Command Line Tools: `xcode-select --install`
- CMake: `brew install cmake`
- NASM (for libjpeg-turbo SIMD): `brew install nasm`

### Building libjpeg-turbo

```bash
cd dependencies/libjpeg-turbo
mkdir build-macos && cd build-macos
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_ARCHITECTURES="arm64" \
      -DENABLE_SHARED=ON \
      ..
make -j$(sysctl -n hw.ncpu)
# Copy libjpeg.62.dylib to libs/macos-arm64/
```

For x64 (Intel) builds:
```bash
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_ARCHITECTURES="x86_64" \
      -DENABLE_SHARED=ON \
      ..
make -j$(sysctl -n hw.ncpu)
# Copy libjpeg.62.dylib to libs/macos-x64/
```

### Building zlib-ng

```bash
cd dependencies/zlib-ng
mkdir build-macos && cd build-macos
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_ARCHITECTURES="arm64" \
      -DZLIB_COMPAT=ON \
      ..
make -j$(sysctl -n hw.ncpu)
# Copy libz.1.dylib to libs/macos-arm64/
```

For x64 (Intel) builds:
```bash
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_ARCHITECTURES="x86_64" \
      -DZLIB_COMPAT=ON \
      ..
make -j$(sysctl -n hw.ncpu)
# Copy libz.1.dylib to libs/macos-x64/
```

## Alternative: Using Homebrew Libraries

On macOS, you can also use system-installed libraries via Homebrew:

```bash
brew install jpeg-turbo zlib
```

The libraries will be located at:
- Apple Silicon: `/opt/homebrew/lib/`
- Intel: `/usr/local/lib/`

## GitHub Actions (Recommended)

For automated cross-platform builds, consider setting up GitHub Actions with a macOS runner:

```yaml
jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: brew install cmake nasm
      - name: Build libraries
        run: |
          # Build scripts here
```

This ensures consistent builds across all platforms without requiring manual macOS access.
