Vampyre Imaging Library — Panvyo fork
=====================================

A fork of the [Vampyre Imaging Library](https://github.com/galfar/imaginglib)
by Marek Mauder, maintained for use in [Panvyo](https://panvyo.com).

**This is not a separate product.** It is upstream Vampyre with the pure-Pascal
codecs swapped for their C counterparts, plus a few bindings. The unit names,
the API and the in-memory pixel layout are all upstream's, unchanged. The
repository is called `dracoola` for historical reasons; the library is still
Vampyre Imaging, and every source file says so.

*FreePascal only* — Delphi support is removed by an explicit `{$FATAL}` guard in
`Source/ImagingOptions.inc`.

Licence
-------

**MPL-2.0**, exactly as upstream. Nothing else. See `License.txt`.

MPL-2.0 is file-level copyleft: modified MPL files must be available in source
form, which they are — this repository is public. Code in separate files that
merely *uses* the library is unaffected.

What differs from upstream
--------------------------

| Area | Change | Why |
|---|---|---|
| **JPEG** | `Source/JpegTurbo/` — libjpeg-turbo bindings replace the bundled pure-Pascal JpegLib | Much faster decode; JPEG is the format a file viewer opens most |
| **ZLib** | `Source/ZLib/zlibng_bindings.pas` behind `ImagingZLib` | zlib-ng is faster; upstream independently added a DLL-zlib path in `5424472` |
| **JPEG 2000** | `Extensions/OpenJpegDynLib.pas` — dynamic OpenJPEG | Avoids vendored `.obj` blobs and their licence surface |
| **LibTiff** | loaded dynamically, versioned SONAME fallbacks, macOS bundle and Homebrew search | Same reason |
| **Diagnostics** | `Source/libloaderror.inc` | Records *why* a codec library failed to load instead of failing silently |

**Channel order is NOT changed.** `TColor24Rec` and `TColor32Rec` are
B,G,R(,A), byte-identical to upstream. Any consumer that assumes otherwise will
transpose red and blue — that mistake has been made once already, see
`UPSTREAM.md`.

### Removed 2026-08-24

`ImagingSimd`, `ImagingSimdResize`, `ImagingThreadPool` and `ImagingMemory` —
about 4,200 lines — were deleted. They were never referenced by any other unit
or by the application, so they were dead weight that this readme nonetheless
advertised as features. If SIMD conversion or threaded resizing is wanted
later, it should be written against a benchmark that shows it is needed and
wired into a real call path.

Staying current with upstream
-----------------------------

See **`UPSTREAM.md`** for the fork point, the merge-base graft, and the recipe
for porting upstream commits. Upstream fixes matter here: roughly 85% of this
code is still theirs.

Credits
-------

Vampyre Imaging Library is by **Marek Mauder** —
<https://github.com/galfar/imaginglib>, <https://imaginglib.sourceforge.io>.
This fork is maintained by Oleg Akopov.
