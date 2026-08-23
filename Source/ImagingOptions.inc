{
  User Options
  Following defines and options can be changed by user.
}

{ Source options }

{$DEFINE USE_INLINE}          // Use function inlining for some functions
                              // works in Free Pascal and Delphi 9+.
{$DEFINE USE_ASM}             // If defined, assembler versions of some
                              // functions will be used (only for x86).

{ Memory allocation options }
{$DEFINE USE_ALIGNED_ALLOC}   // Use aligned memory allocation for image data
                              // Required for SIMD operations (SSE2/AVX2/NEON)
{$DEFINE USE_PLATFORM_ALIGNED_ALLOC}  // Use platform-specific aligned allocation
                              // (_aligned_malloc on Windows, posix_memalign on Unix)
                              // If undefined, falls back to manual alignment

{ SIMD options }
{.$DEFINE USE_SIMD}           // Enable SIMD optimizations (SSE2/AVX2/NEON)
                              // Automatically detected based on target CPU
{.$DEFINE USE_SIMD_RESIZE}    // Enable SIMD image resizing
{.$DEFINE USE_SIMD_CONVERT}   // Enable SIMD pixel format conversion

{ Multi-threading options }
{.$DEFINE IMAGING_MULTITHREADED}  // Enable multi-threaded processing

                              // Debug options: If none of these two are defined
                              // your project settings are used.
{.$DEFINE IMAGING_DEBUG}      // If defined, debug info, range/IO/overflow
                              // checking, stack frames, assertions, and
                              // other debugging options will be turned on.
{.$DEFINE IMAGING_RELEASE}    // If defined, all debug info is off.



(* File format support linking options.
  Define formats which you don't want to be registered automatically (by adding
  Imaging.pas unit to your uses clause).
  Default: most formats are registered = no symbols defined.
  Example: If you want to disable JPEG support just uncomment //{$DEFINE DONT_LINK_JPEG} line
*)

{.$DEFINE DONT_LINK_JPEG}        // link support for Jpeg images
{.$DEFINE DONT_LINK_PNG}         // link support for PNG images
{.$DEFINE DONT_LINK_TARGA}       // link support for Targa images
{.$DEFINE DONT_LINK_BITMAP}      // link support for Windows Bitmap images
{.$DEFINE DONT_LINK_DDS}         // link support for DDS images
{.$DEFINE DONT_LINK_GIF}         // link support for GIF images
{.$DEFINE DONT_LINK_MNG}         // link support for MNG images
{.$DEFINE DONT_LINK_JNG}         // link support for JNG images
{.$DEFINE DONT_LINK_PNM}         // link support for PortableMap images (PBM, PGM, PPM, PAM, PFM)
{.$DEFINE DONT_LINK_RADHDR}      // link support for Radiance HDR/RGBE file format
{.$DEFINE DONT_LINK_QOI}         // link support for Quite OK Image Format

{.$DEFINE DONT_LINK_EXTRAS}  // link support for file formats defined in
                             // Extensions package. Exactly which formats will be
                             // registered depends on settings in
                             // ImagingExtFileFormats.pas unit.

{.$DEFINE DONT_LINK_FILE_FORMATS} // no auto link support of any file format

{
  Auto Options
  Following options and defines are set automatically and some
  are required for Imaging to compile successfully. Do not change
  anything here if you don't know what you are doing.
}

{ Compiler options }

{$ALIGN ON}               // Field alignment: 8 Bytes (in D6+)
{$BOOLEVAL OFF}           // Boolean eval: off
{$EXTENDEDSYNTAX ON}      // Extended syntax: on
{$LONGSTRINGS ON}         // string = AnsiString: on
{$MINENUMSIZE 1}          // Min enum size: 1 B
{$TYPEDADDRESS OFF}       // Typed pointers: off
{$WRITEABLECONST OFF}     // Writeable constants: off

{ FreePascal-only fork - Delphi support removed }
{$IFNDEF FPC}
  {$FATAL This fork of Dracoola Imaging Library requires Free Pascal Compiler}
{$ENDIF}

{$IFDEF DEBUG}
  {$DEFINE IMAGING_DEBUG}
{$ENDIF}

{$IF Defined(IMAGING_DEBUG)}
  {$ASSERTIONS ON}
  {$DEBUGINFO ON}
  {$RANGECHECKS ON}
  {$IOCHECKS ON}
  {$OVERFLOWCHECKS ON}
  {$S+}
  { $CHECKPOINTER is deliberately NOT enabled: it is unsupported on several
    FPC targets and fails the build outright on FPC trunk
    ("Directive CHECKPOINTER+ is not supported on this target").
    Upstream removed it for the same reason - galfar/imaginglib 7358064. }
{$ELSEIF Defined(IMAGING_RELEASE)}
  {$ASSERTIONS OFF}
  {$DEBUGINFO OFF}
  {$RANGECHECKS OFF}
  {$IOCHECKS OFF}
  {$OVERFLOWCHECKS OFF}
  {$S-}
{$IFEND}

{$IF Defined(CPU86) and not Defined(CPUX86)}
  {$DEFINE CPUX86} // Compatibility with Delphi
{$IFEND}

{$IF Defined(CPUX86_64) and not Defined(CPUX64)}
  {$DEFINE CPUX64} // Compatibility with Delphi
{$IFEND}

{$IF Defined(DARWIN) and not Defined(MACOS)}
  {$DEFINE MACOS} // Compatibility with Delphi
{$IFEND}
{$IF Defined(MACOS)}
  {$DEFINE MACOSX}
{$IFEND}


{$IF Defined(WIN32) or Defined(WIN64)}
  {$DEFINE MSWINDOWS} // Compatibility with Delphi
{$IFEND}

{$IF Defined(UNIX) and not Defined(POSIX)}
  {$DEFINE POSIX} // Compatibility with Delphi
{$IFEND}

{ Compiler capabilities - FPC }

// FPC supports inlining
{$DEFINE HAS_INLINE}

// FPC supports advanced records since 2.6.0
{$IF FPC_FULLVERSION >= 20600}
  {$DEFINE HAS_ADVANCED_RECORDS}
{$IFEND}

// FPC supports Delphi compatible operator overloads since 2.6.0
{$IF FPC_FULLVERSION >= 20600}
  {$DEFINE HAS_OPERATOR_OVERLOADING}
{$IFEND}

// FPC supports Delphi compatible generics since 2.6.0
{$IF FPC_FULLVERSION >= 20600}
  {$DEFINE HAS_GENERICS}
{$IFEND}

{ Imaging options check}

{$IFNDEF HAS_INLINE}
  {$UNDEF USE_INLINE}
{$ENDIF}

{$IF not Defined(CPUX86)}
  {$UNDEF USE_ASM}
{$IFEND}

{ Component set - LCL only for FreePascal.
  DRACOOLA_NO_LCL lets an LCL-free host (e.g. Castle Game Engine's
  castle_engine_base, which links Dracoola as its image backend) build the
  Imaging units without dragging in the LCL (ImagingComponents becomes a stub). }
{$IFNDEF DRACOOLA_NO_LCL}
{$DEFINE COMPONENT_SET_LCL}
{$ENDIF}

{ More compiler options - Free Pascal specific }
(* Some options set above (like min enum size) are reset to defaults by setting
   $MODE so they are redeclared here *)

(* FPC Compiler Mode
   Using DELPHI mode for Delphi-compatible syntax:
   - Partial record constant initialization (skipping fields)
   - Automatic pointer array dereferencing (P[I] vs P^[I])
   Note: This is 100% FreePascal - MODE DELPHI only enables
   Delphi-style syntax, NOT the Delphi compiler *)
{$MODE DELPHI}
{$GOTO ON}               // Allow goto
{$PACKRECORDS 8}         // Same as ALIGN 8
{$PACKENUM 4}            // Min enum size: 4 B
{$IFDEF CPU86}
  {$ASMMODE INTEL}       // Intel assembler mode
{$ENDIF}
{$IFDEF CPUX64}
  {$ASMMODE INTEL}       // Intel assembler mode for x64 too
{$ENDIF}

{$INLINE ON}             // Enable inlining


