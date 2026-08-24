# Relationship to upstream Vampyre Imaging Library

This repository is a fork of
[galfar/imaginglib](https://github.com/galfar/imaginglib) (Vampyre Imaging
Library, **MPL-2.0**). Source headers are upstream's, verbatim - this fork
carries no separate branding, and it is not a separate product. The repository
is named `dracoola` for historical reasons only.

## Fork point

**`5a11215` — 2025-05-17, "#38: Upped the sizes of various IO params".**

Established empirically on 2026-08-24: all 24 files this fork never modified
are byte-identical to upstream at that commit, once line endings and the header
rebrand are normalised. Upstream had no commits between 2025-05-17 and
2026-07-16, so the point is unambiguous.

The initial commit here (`079f2de`) is a **squashed snapshot** with no upstream
history, so `git merge-base` returned nothing and comparing the two trees used
to mean diffing them by hand.

That is fixed. A `git replace` graft records `5a11215` as the parent of
`079f2de`, and the replace ref is pushed, so anyone who fetches it gets a
working merge base:

```bash
git remote add upstream https://github.com/galfar/imaginglib.git
git fetch upstream
git fetch origin 'refs/replace/*:refs/replace/*'
git merge-base HEAD upstream/master        # -> 5a11215...
```

## Auditing what upstream has that we do not

With the graft in place this is one command:

```bash
git log --oneline $(git merge-base HEAD upstream/master)..upstream/master
```

Two things still complicate a plain `git cherry-pick`:

1. **Line endings.** Upstream blobs and ours differ, so patches must be
   normalised first.
2. ~~The header rebrand.~~ **Fixed 2026-08-24** — the headers were restored to
   upstream's exact text, so unmodified files are now byte-identical to
   upstream once line endings are normalised. The rebrand `sed` is no longer
   needed in the recipe below.

The reliable recipe, used for the 2026-08-24 port:

```bash
# normalise a scratch copy of our tree
mkdir /tmp/w && cp -r Source Extensions /tmp/w/ && cd /tmp/w
find Source Extensions \( -name '*.pas' -o -name '*.inc' \) \
  -exec sed -i 's/\r$//' {} +      # line endings only - no rebrand any more

# normalise the patch too - upstream blobs are CRLF
git -C <repo> show <commit> | sed 's/\r$//' > /tmp/p.patch
patch -p1 --fuzz=3 < /tmp/p.patch

# then restore CRLF on the way back
sed 's/$/\r/' f > <repo>/f
```

**Check `--fuzz` results.** During the 2026-08-24 port a fuzzy hunk placed a
type declaration *inside* an enum, which only surfaced at compile time.

## What this fork has that upstream does not

These are the reason the fork exists. Do not lose them to an upstream merge.

| Area | Units |
|---|---|
| JPEG | `JpegTurbo/` — libjpeg-turbo instead of the pure-Pascal JpegLib |
| ZLib | `ZLib/zlibng_bindings.pas` — zlib-ng |
| JPEG 2000 | `Extensions/OpenJpegDynLib.pas` — dynamic, not vendored `.obj` |
| Diagnostics | `libloaderror.inc` — records *why* a codec library failed to load |

**Removed 2026-08-24:** `ImagingSimd`, `ImagingSimdResize`, `ImagingThreadPool`
and `ImagingMemory` — ~4,200 lines that no unit and no application ever
referenced. They were dead weight the readme nonetheless advertised as
features. Re-add only against a benchmark and a real call path.

The fork is also **FPC-only** by an explicit `{$FATAL}` guard in
`ImagingOptions.inc`, so upstream's Delphi-specific fixes never apply here, and
`ImagingDirect3D9.pas` / `ImagingFmx.pas` are deliberately absent.

### One fix upstream still needs

`ImagingClasses.pas`, `TMultiImage.ReverseImages`. Upstream loops
`for I := 0 to GetImageCount div 2`, which for an **even** count swaps the
middle pair twice and undoes it. This fork uses `(GetImageCount - 1) div 2`.
Worth reporting upstream.

## Ported from upstream on 2026-08-24

| Upstream | What |
|---|---|
| `9c193d9` | libtiff binding ABI — `thandle_t` must be pointer-sized |
| `318c312` (#38) | `PBuffer` + `PtrInt` offsets for images past 2 GB |
| `6324e4e`, `a2c40f0`, `bc2a95b` (#52/#38) | BigTIFF read and write |
| `7358064` (#51) | drop `{$CHECKPOINTER ON}` — fatal on FPC trunk |
| `95808a5` | `ImagingGif` — also fixes a real `Height`-vs-`MaxWidth` comparison |
| `5424472` (#43) | renamed `dzlib` → `ImagingZLib` to match upstream |

Deliberately skipped: `ImagingDirect3D9.pas`, `ImagingFmx.pas`, the Delphi-only
compile fixes, and the vendored `J2KObjects` / `LibTiff/Compiled` static blobs
(this fork loads those dynamically on purpose).

Full reasoning in the workspace at
`DesignDocs/DRACOOLA-UPSTREAM-AUDIT-2026-08-23.md`.
