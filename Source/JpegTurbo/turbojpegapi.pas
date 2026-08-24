{
  Vampyre Imaging Library - TurboJPEG API Bindings
  FreePascal bindings for libjpeg-turbo's native TurboJPEG API

  TurboJPEG is a simpler, higher-level API that doesn't require dealing with
  complex C structs. It uses opaque handles and simple function calls.

  This unit provides dynamic linking to turbojpeg:
    - Windows: turbojpeg.dll
    - Linux: libturbojpeg.so.0
    - macOS: libturbojpeg.0.dylib

  The TurboJPEG API (tj3*) is the recommended way to use libjpeg-turbo.
  It provides better performance and doesn't have the struct alignment
  issues of the legacy libjpeg API.
}
unit turbojpegapi;

{$I ..\ImagingOptions.inc}

interface

uses
  SysUtils, Classes;

const
  { Library names for different platforms }
  {$IFDEF MSWINDOWS}
  TURBOJPEG_LIB = 'turbojpeg.dll';
  {$ENDIF}
  {$IFDEF LINUX}
  TURBOJPEG_LIB = 'libturbojpeg.so.0';
  {$ENDIF}
  {$IFDEF DARWIN}
  TURBOJPEG_LIB = 'libturbojpeg.0.dylib';
  {$ENDIF}

type
  { TurboJPEG handle - opaque pointer }
  tjhandle = Pointer;

  { Initialization options }
  TJINIT = (
    TJINIT_COMPRESS = 0,    { Initialize for compression }
    TJINIT_DECOMPRESS = 1,  { Initialize for decompression }
    TJINIT_TRANSFORM = 2    { Initialize for lossless transformation }
  );

  { Chrominance subsampling options }
  TJSAMP = (
    TJSAMP_444 = 0,     { 4:4:4 - no subsampling }
    TJSAMP_422 = 1,     { 4:2:2 horizontal subsampling }
    TJSAMP_420 = 2,     { 4:2:0 subsampling }
    TJSAMP_GRAY = 3,    { Grayscale }
    TJSAMP_440 = 4,     { 4:4:0 vertical subsampling }
    TJSAMP_411 = 5,     { 4:1:1 subsampling }
    TJSAMP_441 = 6      { 4:4:1 subsampling }
  );

  { Pixel formats }
  TJPF = (
    TJPF_RGB = 0,       { RGB (24-bit) }
    TJPF_BGR = 1,       { BGR (24-bit) }
    TJPF_RGBX = 2,      { RGBX (32-bit) }
    TJPF_BGRX = 3,      { BGRX (32-bit) }
    TJPF_XBGR = 4,      { XBGR (32-bit) }
    TJPF_XRGB = 5,      { XRGB (32-bit) }
    TJPF_GRAY = 6,      { Grayscale (8-bit) }
    TJPF_RGBA = 7,      { RGBA (32-bit) }
    TJPF_BGRA = 8,      { BGRA (32-bit) }
    TJPF_ABGR = 9,      { ABGR (32-bit) }
    TJPF_ARGB = 10,     { ARGB (32-bit) }
    TJPF_CMYK = 11      { CMYK (32-bit) }
  );

  { JPEG colorspaces }
  TJCS = (
    TJCS_RGB = 0,       { RGB colorspace }
    TJCS_YCbCr = 1,     { YCbCr colorspace }
    TJCS_GRAY = 2,      { Grayscale colorspace }
    TJCS_CMYK = 3,      { CMYK colorspace }
    TJCS_YCCK = 4       { YCCK colorspace }
  );

  { Error codes }
  TJERR = (
    TJERR_WARNING = 0,  { Non-fatal warning }
    TJERR_FATAL = 1     { Fatal error }
  );

  { Parameters }
  TJPARAM = (
    TJPARAM_STOPONWARNING = 0,
    TJPARAM_BOTTOMUP = 1,
    TJPARAM_NOREALLOC = 2,
    TJPARAM_QUALITY = 3,
    TJPARAM_SUBSAMP = 4,
    TJPARAM_JPEGWIDTH = 5,
    TJPARAM_JPEGHEIGHT = 6,
    TJPARAM_PRECISION = 7,
    TJPARAM_COLORSPACE = 8,
    TJPARAM_FASTUPSAMPLE = 9,
    TJPARAM_FASTDCT = 10,
    TJPARAM_OPTIMIZE = 11,
    TJPARAM_PROGRESSIVE = 12,
    TJPARAM_SCANLIMIT = 13,
    TJPARAM_ARITHMETIC = 14,
    TJPARAM_LOSSLESS = 15,
    TJPARAM_LOSSLESSPSV = 16,
    TJPARAM_LOSSLESSPT = 17,
    TJPARAM_RESTARTBLOCKS = 18,
    TJPARAM_RESTARTROWS = 19,
    TJPARAM_XDENSITY = 20,
    TJPARAM_YDENSITY = 21,
    TJPARAM_DENSITYUNITS = 22,
    TJPARAM_MAXMEMORY = 23,
    TJPARAM_MAXPIXELS = 24,
    TJPARAM_SAVEMARKERS = 25
  );

  { Scaling factor structure }
  tjscalingfactor = record
    num: Integer;
    denom: Integer;
  end;
  Ptjscalingfactor = ^tjscalingfactor;

const
  { Pixel sizes for each format }
  tjPixelSize: array[TJPF_RGB..TJPF_CMYK] of Integer = (
    3,  { TJPF_RGB }
    3,  { TJPF_BGR }
    4,  { TJPF_RGBX }
    4,  { TJPF_BGRX }
    4,  { TJPF_XBGR }
    4,  { TJPF_XRGB }
    1,  { TJPF_GRAY }
    4,  { TJPF_RGBA }
    4,  { TJPF_BGRA }
    4,  { TJPF_ABGR }
    4,  { TJPF_ARGB }
    4   { TJPF_CMYK }
  );

  { Red offset for each pixel format (-1 if no red component) }
  tjRedOffset: array[TJPF_RGB..TJPF_CMYK] of Integer = (
    0, 2, 0, 2, 3, 1, -1, 0, 2, 3, 1, -1
  );

  { Green offset for each pixel format (-1 if no green component) }
  tjGreenOffset: array[TJPF_RGB..TJPF_CMYK] of Integer = (
    1, 1, 1, 1, 2, 2, -1, 1, 1, 2, 2, -1
  );

  { Blue offset for each pixel format (-1 if no blue component) }
  tjBlueOffset: array[TJPF_RGB..TJPF_CMYK] of Integer = (
    2, 0, 2, 0, 1, 3, -1, 2, 0, 1, 3, -1
  );

  { Alpha offset for each pixel format (-1 if no alpha component) }
  tjAlphaOffset: array[TJPF_RGB..TJPF_CMYK] of Integer = (
    -1, -1, -1, -1, -1, -1, -1, 3, 3, 0, 0, -1
  );

  { MCU width for each subsampling option }
  tjMCUWidth: array[TJSAMP_444..TJSAMP_441] of Integer = (
    8, 16, 16, 8, 8, 32, 8
  );

  { MCU height for each subsampling option }
  tjMCUHeight: array[TJSAMP_444..TJSAMP_441] of Integer = (
    8, 8, 16, 8, 16, 8, 32
  );

{ Library loading and initialization }
{ Why the TurboJPEG library could not be loaded - '' while it is fine. Named
  file plus the operating-system reason, for reporting to the user. }
function TurboJpegLoadError: string;

function LoadTurboJpegLibrary: Boolean;
procedure UnloadTurboJpegLibrary;
function IsTurboJpegLibraryLoaded: Boolean;

{ TurboJPEG 3.0 API functions }

{ Create a TurboJPEG instance }
function tj3Init(initType: Integer): tjhandle; cdecl;

{ Destroy a TurboJPEG instance }
procedure tj3Destroy(handle: tjhandle); cdecl;

{ Get error message }
function tj3GetErrorStr(handle: tjhandle): PAnsiChar; cdecl;

{ Get error code }
function tj3GetErrorCode(handle: tjhandle): Integer; cdecl;

{ Set parameter }
function tj3Set(handle: tjhandle; param: Integer; value: Integer): Integer; cdecl;

{ Get parameter }
function tj3Get(handle: tjhandle; param: Integer): Integer; cdecl;

{ Allocate buffer }
function tj3Alloc(bytes: NativeUInt): Pointer; cdecl;

{ Free buffer }
procedure tj3Free(buffer: Pointer); cdecl;

{ Get maximum JPEG buffer size }
function tj3JPEGBufSize(width: Integer; height: Integer; jpegSubsamp: Integer): NativeUInt; cdecl;

{ Compress 8-bit image to JPEG }
function tj3Compress8(handle: tjhandle; srcBuf: PByte; width: Integer;
  pitch: Integer; height: Integer; pixelFormat: Integer;
  var jpegBuf: PByte; var jpegSize: NativeUInt): Integer; cdecl;

{ Read JPEG header }
function tj3DecompressHeader(handle: tjhandle; jpegBuf: PByte;
  jpegSize: NativeUInt): Integer; cdecl;

{ Get scaling factors }
function tj3GetScalingFactors(var numScalingFactors: Integer): Ptjscalingfactor; cdecl;

{ Set scaling factor }
function tj3SetScalingFactor(handle: tjhandle; scalingFactor: tjscalingfactor): Integer; cdecl;

{ Decompress JPEG to 8-bit image }
function tj3Decompress8(handle: tjhandle; jpegBuf: PByte;
  jpegSize: NativeUInt; dstBuf: PByte; pitch: Integer;
  pixelFormat: Integer): Integer; cdecl;

{ Helper function to scale dimensions }
function TJScaled(dimension: Integer; scalingFactor: tjscalingfactor): Integer; inline;

implementation

uses
  dynlibs{$IFDEF MSWINDOWS}, Windows{$ENDIF};

var
  TurboJpegLibHandle: TLibHandle = NilHandle;
  GTurboJpegLoadError: string = '';

  { Function pointers }
  _tj3Init: function(initType: Integer): tjhandle; cdecl;
  _tj3Destroy: procedure(handle: tjhandle); cdecl;
  _tj3GetErrorStr: function(handle: tjhandle): PAnsiChar; cdecl;
  _tj3GetErrorCode: function(handle: tjhandle): Integer; cdecl;
  _tj3Set: function(handle: tjhandle; param: Integer; value: Integer): Integer; cdecl;
  _tj3Get: function(handle: tjhandle; param: Integer): Integer; cdecl;
  _tj3Alloc: function(bytes: NativeUInt): Pointer; cdecl;
  _tj3Free: procedure(buffer: Pointer); cdecl;
  _tj3JPEGBufSize: function(width: Integer; height: Integer; jpegSubsamp: Integer): NativeUInt; cdecl;
  _tj3Compress8: function(handle: tjhandle; srcBuf: PByte; width: Integer;
    pitch: Integer; height: Integer; pixelFormat: Integer;
    var jpegBuf: PByte; var jpegSize: NativeUInt): Integer; cdecl;
  _tj3DecompressHeader: function(handle: tjhandle; jpegBuf: PByte;
    jpegSize: NativeUInt): Integer; cdecl;
  _tj3GetScalingFactors: function(var numScalingFactors: Integer): Ptjscalingfactor; cdecl;
  _tj3SetScalingFactor: function(handle: tjhandle; scalingFactor: tjscalingfactor): Integer; cdecl;
  _tj3Decompress8: function(handle: tjhandle; jpegBuf: PByte;
    jpegSize: NativeUInt; dstBuf: PByte; pitch: Integer;
    pixelFormat: Integer): Integer; cdecl;


{$I ../libloaderror.inc}

function LoadTurboJpegLibrary: Boolean;
begin
  if TurboJpegLibHandle <> NilHandle then
  begin
    Result := True;
    Exit;
  end;

  TurboJpegLibHandle := LoadLibrary(TURBOJPEG_LIB);
  if TurboJpegLibHandle = NilHandle then
  begin
    { Do not fail mute: JPEG decoding disappearing with no message anywhere is
      indistinguishable from a corrupt file to the user. }
    GTurboJpegLoadError := DescribeLibLoadFailure(TURBOJPEG_LIB);
    Result := False;
    Exit;
  end;

  @_tj3Init := GetProcAddress(TurboJpegLibHandle, 'tj3Init');
  @_tj3Destroy := GetProcAddress(TurboJpegLibHandle, 'tj3Destroy');
  @_tj3GetErrorStr := GetProcAddress(TurboJpegLibHandle, 'tj3GetErrorStr');
  @_tj3GetErrorCode := GetProcAddress(TurboJpegLibHandle, 'tj3GetErrorCode');
  @_tj3Set := GetProcAddress(TurboJpegLibHandle, 'tj3Set');
  @_tj3Get := GetProcAddress(TurboJpegLibHandle, 'tj3Get');
  @_tj3Alloc := GetProcAddress(TurboJpegLibHandle, 'tj3Alloc');
  @_tj3Free := GetProcAddress(TurboJpegLibHandle, 'tj3Free');
  @_tj3JPEGBufSize := GetProcAddress(TurboJpegLibHandle, 'tj3JPEGBufSize');
  @_tj3Compress8 := GetProcAddress(TurboJpegLibHandle, 'tj3Compress8');
  @_tj3DecompressHeader := GetProcAddress(TurboJpegLibHandle, 'tj3DecompressHeader');
  @_tj3GetScalingFactors := GetProcAddress(TurboJpegLibHandle, 'tj3GetScalingFactors');
  @_tj3SetScalingFactor := GetProcAddress(TurboJpegLibHandle, 'tj3SetScalingFactor');
  @_tj3Decompress8 := GetProcAddress(TurboJpegLibHandle, 'tj3Decompress8');

  { Check if essential functions were loaded }
  Result := Assigned(_tj3Init) and
            Assigned(_tj3Destroy) and
            Assigned(_tj3Compress8) and
            Assigned(_tj3Decompress8) and
            Assigned(_tj3DecompressHeader) and
            Assigned(_tj3Set) and
            Assigned(_tj3Get);

  if not Result then
    UnloadTurboJpegLibrary;
end;

procedure UnloadTurboJpegLibrary;
begin
  if TurboJpegLibHandle <> NilHandle then
  begin
    FreeLibrary(TurboJpegLibHandle);
    TurboJpegLibHandle := NilHandle;
  end;

  @_tj3Init := nil;
  @_tj3Destroy := nil;
  @_tj3GetErrorStr := nil;
  @_tj3GetErrorCode := nil;
  @_tj3Set := nil;
  @_tj3Get := nil;
  @_tj3Alloc := nil;
  @_tj3Free := nil;
  @_tj3JPEGBufSize := nil;
  @_tj3Compress8 := nil;
  @_tj3DecompressHeader := nil;
  @_tj3GetScalingFactors := nil;
  @_tj3SetScalingFactor := nil;
  @_tj3Decompress8 := nil;
end;

function IsTurboJpegLibraryLoaded: Boolean;
begin
  Result := TurboJpegLibHandle <> NilHandle;
end;

{ Wrapper functions }

function tj3Init(initType: Integer): tjhandle; cdecl;
begin
  if Assigned(_tj3Init) then
    Result := _tj3Init(initType)
  else
    Result := nil;
end;

procedure tj3Destroy(handle: tjhandle); cdecl;
begin
  if Assigned(_tj3Destroy) then
    _tj3Destroy(handle);
end;

function tj3GetErrorStr(handle: tjhandle): PAnsiChar; cdecl;
begin
  if Assigned(_tj3GetErrorStr) then
    Result := _tj3GetErrorStr(handle)
  else
    Result := nil;
end;

function tj3GetErrorCode(handle: tjhandle): Integer; cdecl;
begin
  if Assigned(_tj3GetErrorCode) then
    Result := _tj3GetErrorCode(handle)
  else
    Result := -1;
end;

function tj3Set(handle: tjhandle; param: Integer; value: Integer): Integer; cdecl;
begin
  if Assigned(_tj3Set) then
    Result := _tj3Set(handle, param, value)
  else
    Result := -1;
end;

function tj3Get(handle: tjhandle; param: Integer): Integer; cdecl;
begin
  if Assigned(_tj3Get) then
    Result := _tj3Get(handle, param)
  else
    Result := -1;
end;

function tj3Alloc(bytes: NativeUInt): Pointer; cdecl;
begin
  if Assigned(_tj3Alloc) then
    Result := _tj3Alloc(bytes)
  else
    Result := nil;
end;

procedure tj3Free(buffer: Pointer); cdecl;
begin
  if Assigned(_tj3Free) then
    _tj3Free(buffer);
end;

function tj3JPEGBufSize(width: Integer; height: Integer; jpegSubsamp: Integer): NativeUInt; cdecl;
begin
  if Assigned(_tj3JPEGBufSize) then
    Result := _tj3JPEGBufSize(width, height, jpegSubsamp)
  else
    Result := 0;
end;

function tj3Compress8(handle: tjhandle; srcBuf: PByte; width: Integer;
  pitch: Integer; height: Integer; pixelFormat: Integer;
  var jpegBuf: PByte; var jpegSize: NativeUInt): Integer; cdecl;
begin
  if Assigned(_tj3Compress8) then
    Result := _tj3Compress8(handle, srcBuf, width, pitch, height, pixelFormat, jpegBuf, jpegSize)
  else
    Result := -1;
end;

function tj3DecompressHeader(handle: tjhandle; jpegBuf: PByte;
  jpegSize: NativeUInt): Integer; cdecl;
begin
  if Assigned(_tj3DecompressHeader) then
    Result := _tj3DecompressHeader(handle, jpegBuf, jpegSize)
  else
    Result := -1;
end;

function tj3GetScalingFactors(var numScalingFactors: Integer): Ptjscalingfactor; cdecl;
begin
  if Assigned(_tj3GetScalingFactors) then
    Result := _tj3GetScalingFactors(numScalingFactors)
  else
  begin
    numScalingFactors := 0;
    Result := nil;
  end;
end;

function tj3SetScalingFactor(handle: tjhandle; scalingFactor: tjscalingfactor): Integer; cdecl;
begin
  if Assigned(_tj3SetScalingFactor) then
    Result := _tj3SetScalingFactor(handle, scalingFactor)
  else
    Result := -1;
end;

function tj3Decompress8(handle: tjhandle; jpegBuf: PByte;
  jpegSize: NativeUInt; dstBuf: PByte; pitch: Integer;
  pixelFormat: Integer): Integer; cdecl;
begin
  if Assigned(_tj3Decompress8) then
    Result := _tj3Decompress8(handle, jpegBuf, jpegSize, dstBuf, pitch, pixelFormat)
  else
    Result := -1;
end;

function TJScaled(dimension: Integer; scalingFactor: tjscalingfactor): Integer;
begin
  Result := (dimension * scalingFactor.num + scalingFactor.denom - 1) div scalingFactor.denom;
end;

function TurboJpegLoadError: string;
begin
  Result := GTurboJpegLoadError;
end;

initialization
  LoadTurboJpegLibrary;

finalization
  UnloadTurboJpegLibrary;


end.
