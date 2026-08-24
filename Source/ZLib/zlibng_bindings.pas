{
  Vampyre Imaging Library - zlib-ng Bindings
  FreePascal bindings for zlib-ng library

  zlib-ng is a fork of zlib with optimizations including:
  - SIMD implementations (SSE2, AVX2, NEON, etc.)
  - Modern compiler optimizations
  - API compatible with zlib when built with ZLIB_COMPAT=ON

  This unit provides dynamic linking to zlib-ng or standard zlib:
    - Windows: zlib1.dll (compat mode) or zlib-ng2.dll
    - Linux: libz.so.1 (compat/system) or libz-ng.so.2
    - macOS: libz.1.dylib (system) or libz-ng.2.dylib
}
unit zlibng_bindings;

{$I ..\ImagingOptions.inc}

interface

uses
  SysUtils;

const
  { Library names for different platforms }
  {$IFDEF MSWINDOWS}
  ZLIB_LIB_COMPAT = 'zlib1.dll';
  ZLIB_LIB_NG = 'zlib-ng2.dll';
  {$ENDIF}
  {$IFDEF LINUX}
  ZLIB_LIB_COMPAT = 'libz.so.1';
  ZLIB_LIB_NG = 'libz-ng.so.2';
  {$ENDIF}
  {$IFDEF DARWIN}
  ZLIB_LIB_COMPAT = 'libz.1.dylib';
  ZLIB_LIB_NG = 'libz-ng.2.dylib';
  {$ENDIF}

  { zlib version }
  ZLIB_VERSION: PAnsiChar = '1.3.1';

  { Flush values }
  Z_NO_FLUSH      = 0;
  Z_PARTIAL_FLUSH = 1;
  Z_SYNC_FLUSH    = 2;
  Z_FULL_FLUSH    = 3;
  Z_FINISH        = 4;
  Z_BLOCK         = 5;
  Z_TREES         = 6;

  { Return codes }
  Z_OK            =  0;
  Z_STREAM_END    =  1;
  Z_NEED_DICT     =  2;
  Z_ERRNO         = -1;
  Z_STREAM_ERROR  = -2;
  Z_DATA_ERROR    = -3;
  Z_MEM_ERROR     = -4;
  Z_BUF_ERROR     = -5;
  Z_VERSION_ERROR = -6;

  { Compression levels }
  Z_NO_COMPRESSION       =  0;
  Z_BEST_SPEED           =  1;
  Z_BEST_COMPRESSION     =  9;
  Z_DEFAULT_COMPRESSION  = -1;

  { Compression strategy }
  Z_FILTERED            = 1;
  Z_HUFFMAN_ONLY        = 2;
  Z_RLE                 = 3;
  Z_FIXED               = 4;
  Z_DEFAULT_STRATEGY    = 0;

  { Data type }
  Z_BINARY   = 0;
  Z_TEXT     = 1;
  Z_ASCII    = Z_TEXT;
  Z_UNKNOWN  = 2;

  { Compression method }
  Z_DEFLATED = 8;

  { Window bits }
  MAX_WBITS = 15;

  { Memory level }
  DEF_MEM_LEVEL = 8;
  MAX_MEM_LEVEL = 9;

type
  { Basic types }
  z_size_t = NativeUInt;
  uInt = Cardinal;
  uLong = LongWord;
  Bytef = Byte;
  pBytef = ^Bytef;
  voidpf = Pointer;

  { Allocation functions }
  alloc_func = function(opaque: voidpf; items, size: uInt): voidpf; cdecl;
  free_func = procedure(opaque: voidpf; address: voidpf); cdecl;

  { z_stream structure }
  z_stream = record
    next_in: pBytef;        { next input byte }
    avail_in: uInt;         { number of bytes available at next_in }
    total_in: uLong;        { total number of input bytes read so far }

    next_out: pBytef;       { next output byte will go here }
    avail_out: uInt;        { remaining free space at next_out }
    total_out: uLong;       { total number of bytes output so far }

    msg: PAnsiChar;         { last error message, NULL if no error }
    internal_state: Pointer; { not visible by applications }

    zalloc: alloc_func;     { used to allocate the internal state }
    zfree: free_func;       { used to free the internal state }
    opaque: voidpf;         { private data object passed to zalloc and zfree }

    data_type: Integer;     { best guess about the data type: binary or text
                              for deflate, or the decoding state for inflate }
    adler: uLong;           { Adler-32 or CRC-32 value of the uncompressed data }
    reserved: uLong;        { reserved for future use }
  end;
  z_streamp = ^z_stream;
  TZStreamRec = z_stream;
  PZStreamRec = ^TZStreamRec;

  { gz_header structure for gzip files }
  gz_header = record
    text: Integer;          { true if compressed data believed to be text }
    time: uLong;            { modification time }
    xflags: Integer;        { extra flags (not used when writing a gzip file) }
    os: Integer;            { operating system }
    extra: pBytef;          { pointer to extra field or Z_NULL if none }
    extra_len: uInt;        { extra field length (valid if extra != Z_NULL) }
    extra_max: uInt;        { space at extra (only when reading header) }
    name: PAnsiChar;        { pointer to zero-terminated file name or Z_NULL }
    name_max: uInt;         { space at name (only when reading header) }
    comment: PAnsiChar;     { pointer to zero-terminated comment or Z_NULL }
    comm_max: uInt;         { space at comment (only when reading header) }
    hcrc: Integer;          { true if there was or will be a header crc }
    done: Integer;          { true when done reading gzip header }
  end;
  gz_headerp = ^gz_header;

{ Library loading and initialization }
{ Why no zlib could be loaded - '' while one is available. Note that a failure
  here is usually harmless: callers fall back to the compiled-in paszlib. }
function ZlibLoadError: string;

function LoadZlibLibrary: Boolean;
procedure UnloadZlibLibrary;
function IsZlibLibraryLoaded: Boolean;
function GetZlibVersion: string;
function IsZlibNG: Boolean;

{ Version function }
function zlibVersion: PAnsiChar; cdecl;

{ Basic compression/decompression functions }
function deflateInit_(var strm: z_stream; level: Integer;
  const version: PAnsiChar; stream_size: Integer): Integer; cdecl;
function deflate(var strm: z_stream; flush: Integer): Integer; cdecl;
function deflateEnd(var strm: z_stream): Integer; cdecl;

function inflateInit_(var strm: z_stream;
  const version: PAnsiChar; stream_size: Integer): Integer; cdecl;
function inflate(var strm: z_stream; flush: Integer): Integer; cdecl;
function inflateEnd(var strm: z_stream): Integer; cdecl;

{ Advanced compression functions }
function deflateInit2_(var strm: z_stream; level, method, windowBits,
  memLevel, strategy: Integer; const version: PAnsiChar;
  stream_size: Integer): Integer; cdecl;
function deflateSetDictionary(var strm: z_stream; const dictionary: pBytef;
  dictLength: uInt): Integer; cdecl;
function deflateCopy(var dest, source: z_stream): Integer; cdecl;
function deflateReset(var strm: z_stream): Integer; cdecl;
function deflateParams(var strm: z_stream; level, strategy: Integer): Integer; cdecl;
function deflateTune(var strm: z_stream; good_length, max_lazy,
  nice_length, max_chain: Integer): Integer; cdecl;
function deflateBound(var strm: z_stream; sourceLen: uLong): uLong; cdecl;
function deflatePrime(var strm: z_stream; bits, value: Integer): Integer; cdecl;
function deflateSetHeader(var strm: z_stream; var head: gz_header): Integer; cdecl;

{ Advanced decompression functions }
function inflateInit2_(var strm: z_stream; windowBits: Integer;
  const version: PAnsiChar; stream_size: Integer): Integer; cdecl;
function inflateSetDictionary(var strm: z_stream; const dictionary: pBytef;
  dictLength: uInt): Integer; cdecl;
function inflateSync(var strm: z_stream): Integer; cdecl;
function inflateCopy(var dest, source: z_stream): Integer; cdecl;
function inflateReset(var strm: z_stream): Integer; cdecl;
function inflateReset2(var strm: z_stream; windowBits: Integer): Integer; cdecl;
function inflatePrime(var strm: z_stream; bits, value: Integer): Integer; cdecl;
function inflateMark(var strm: z_stream): LongInt; cdecl;
function inflateGetHeader(var strm: z_stream; var head: gz_header): Integer; cdecl;

{ Utility functions }
function compress(dest: pBytef; var destLen: uLong;
  const source: pBytef; sourceLen: uLong): Integer; cdecl;
function compress2(dest: pBytef; var destLen: uLong;
  const source: pBytef; sourceLen: uLong; level: Integer): Integer; cdecl;
function compressBound(sourceLen: uLong): uLong; cdecl;
function uncompress(dest: pBytef; var destLen: uLong;
  const source: pBytef; sourceLen: uLong): Integer; cdecl;

{ Checksum functions }
function adler32(adler: uLong; const buf: pBytef; len: uInt): uLong; cdecl;
function adler32_combine(adler1, adler2: uLong; len2: LongInt): uLong; cdecl;
function crc32(crc: uLong; const buf: pBytef; len: uInt): uLong; cdecl;
function crc32_combine(crc1, crc2: uLong; len2: LongInt): uLong; cdecl;

{ Helper macros as functions }
function deflateInit(var strm: z_stream; level: Integer): Integer;
function inflateInit(var strm: z_stream): Integer;
function deflateInit2(var strm: z_stream; level, method, windowBits,
  memLevel, strategy: Integer): Integer;
function inflateInit2(var strm: z_stream; windowBits: Integer): Integer;

implementation

uses
  dynlibs{$IFDEF MSWINDOWS}, Windows{$ENDIF};

var
  ZlibLibHandle: TLibHandle = NilHandle;
  GZlibLoadError: string = '';
  UsingZlibNG: Boolean = False;

  { Function pointers }
  _zlibVersion: function: PAnsiChar; cdecl;
  _deflateInit_: function(var strm: z_stream; level: Integer;
    const version: PAnsiChar; stream_size: Integer): Integer; cdecl;
  _deflate: function(var strm: z_stream; flush: Integer): Integer; cdecl;
  _deflateEnd: function(var strm: z_stream): Integer; cdecl;
  _inflateInit_: function(var strm: z_stream;
    const version: PAnsiChar; stream_size: Integer): Integer; cdecl;
  _inflate: function(var strm: z_stream; flush: Integer): Integer; cdecl;
  _inflateEnd: function(var strm: z_stream): Integer; cdecl;
  _deflateInit2_: function(var strm: z_stream; level, method, windowBits,
    memLevel, strategy: Integer; const version: PAnsiChar;
    stream_size: Integer): Integer; cdecl;
  _deflateSetDictionary: function(var strm: z_stream; const dictionary: pBytef;
    dictLength: uInt): Integer; cdecl;
  _deflateCopy: function(var dest, source: z_stream): Integer; cdecl;
  _deflateReset: function(var strm: z_stream): Integer; cdecl;
  _deflateParams: function(var strm: z_stream; level, strategy: Integer): Integer; cdecl;
  _deflateTune: function(var strm: z_stream; good_length, max_lazy,
    nice_length, max_chain: Integer): Integer; cdecl;
  _deflateBound: function(var strm: z_stream; sourceLen: uLong): uLong; cdecl;
  _deflatePrime: function(var strm: z_stream; bits, value: Integer): Integer; cdecl;
  _deflateSetHeader: function(var strm: z_stream; var head: gz_header): Integer; cdecl;
  _inflateInit2_: function(var strm: z_stream; windowBits: Integer;
    const version: PAnsiChar; stream_size: Integer): Integer; cdecl;
  _inflateSetDictionary: function(var strm: z_stream; const dictionary: pBytef;
    dictLength: uInt): Integer; cdecl;
  _inflateSync: function(var strm: z_stream): Integer; cdecl;
  _inflateCopy: function(var dest, source: z_stream): Integer; cdecl;
  _inflateReset: function(var strm: z_stream): Integer; cdecl;
  _inflateReset2: function(var strm: z_stream; windowBits: Integer): Integer; cdecl;
  _inflatePrime: function(var strm: z_stream; bits, value: Integer): Integer; cdecl;
  _inflateMark: function(var strm: z_stream): LongInt; cdecl;
  _inflateGetHeader: function(var strm: z_stream; var head: gz_header): Integer; cdecl;
  _compress: function(dest: pBytef; var destLen: uLong;
    const source: pBytef; sourceLen: uLong): Integer; cdecl;
  _compress2: function(dest: pBytef; var destLen: uLong;
    const source: pBytef; sourceLen: uLong; level: Integer): Integer; cdecl;
  _compressBound: function(sourceLen: uLong): uLong; cdecl;
  _uncompress: function(dest: pBytef; var destLen: uLong;
    const source: pBytef; sourceLen: uLong): Integer; cdecl;
  _adler32: function(adler: uLong; const buf: pBytef; len: uInt): uLong; cdecl;
  _adler32_combine: function(adler1, adler2: uLong; len2: LongInt): uLong; cdecl;
  _crc32: function(crc: uLong; const buf: pBytef; len: uInt): uLong; cdecl;
  _crc32_combine: function(crc1, crc2: uLong; len2: LongInt): uLong; cdecl;

procedure ClearFunctionPointers;
begin
  @_zlibVersion := nil;
  @_deflateInit_ := nil;
  @_deflate := nil;
  @_deflateEnd := nil;
  @_inflateInit_ := nil;
  @_inflate := nil;
  @_inflateEnd := nil;
  @_deflateInit2_ := nil;
  @_deflateSetDictionary := nil;
  @_deflateCopy := nil;
  @_deflateReset := nil;
  @_deflateParams := nil;
  @_deflateTune := nil;
  @_deflateBound := nil;
  @_deflatePrime := nil;
  @_deflateSetHeader := nil;
  @_inflateInit2_ := nil;
  @_inflateSetDictionary := nil;
  @_inflateSync := nil;
  @_inflateCopy := nil;
  @_inflateReset := nil;
  @_inflateReset2 := nil;
  @_inflatePrime := nil;
  @_inflateMark := nil;
  @_inflateGetHeader := nil;
  @_compress := nil;
  @_compress2 := nil;
  @_compressBound := nil;
  @_uncompress := nil;
  @_adler32 := nil;
  @_adler32_combine := nil;
  @_crc32 := nil;
  @_crc32_combine := nil;
end;

function LoadFunctions: Boolean;
begin
  @_zlibVersion := GetProcAddress(ZlibLibHandle, 'zlibVersion');
  @_deflateInit_ := GetProcAddress(ZlibLibHandle, 'deflateInit_');
  @_deflate := GetProcAddress(ZlibLibHandle, 'deflate');
  @_deflateEnd := GetProcAddress(ZlibLibHandle, 'deflateEnd');
  @_inflateInit_ := GetProcAddress(ZlibLibHandle, 'inflateInit_');
  @_inflate := GetProcAddress(ZlibLibHandle, 'inflate');
  @_inflateEnd := GetProcAddress(ZlibLibHandle, 'inflateEnd');
  @_deflateInit2_ := GetProcAddress(ZlibLibHandle, 'deflateInit2_');
  @_deflateSetDictionary := GetProcAddress(ZlibLibHandle, 'deflateSetDictionary');
  @_deflateCopy := GetProcAddress(ZlibLibHandle, 'deflateCopy');
  @_deflateReset := GetProcAddress(ZlibLibHandle, 'deflateReset');
  @_deflateParams := GetProcAddress(ZlibLibHandle, 'deflateParams');
  @_deflateTune := GetProcAddress(ZlibLibHandle, 'deflateTune');
  @_deflateBound := GetProcAddress(ZlibLibHandle, 'deflateBound');
  @_deflatePrime := GetProcAddress(ZlibLibHandle, 'deflatePrime');
  @_deflateSetHeader := GetProcAddress(ZlibLibHandle, 'deflateSetHeader');
  @_inflateInit2_ := GetProcAddress(ZlibLibHandle, 'inflateInit2_');
  @_inflateSetDictionary := GetProcAddress(ZlibLibHandle, 'inflateSetDictionary');
  @_inflateSync := GetProcAddress(ZlibLibHandle, 'inflateSync');
  @_inflateCopy := GetProcAddress(ZlibLibHandle, 'inflateCopy');
  @_inflateReset := GetProcAddress(ZlibLibHandle, 'inflateReset');
  @_inflateReset2 := GetProcAddress(ZlibLibHandle, 'inflateReset2');
  @_inflatePrime := GetProcAddress(ZlibLibHandle, 'inflatePrime');
  @_inflateMark := GetProcAddress(ZlibLibHandle, 'inflateMark');
  @_inflateGetHeader := GetProcAddress(ZlibLibHandle, 'inflateGetHeader');
  @_compress := GetProcAddress(ZlibLibHandle, 'compress');
  @_compress2 := GetProcAddress(ZlibLibHandle, 'compress2');
  @_compressBound := GetProcAddress(ZlibLibHandle, 'compressBound');
  @_uncompress := GetProcAddress(ZlibLibHandle, 'uncompress');
  @_adler32 := GetProcAddress(ZlibLibHandle, 'adler32');
  @_adler32_combine := GetProcAddress(ZlibLibHandle, 'adler32_combine');
  @_crc32 := GetProcAddress(ZlibLibHandle, 'crc32');
  @_crc32_combine := GetProcAddress(ZlibLibHandle, 'crc32_combine');

  { Check if essential functions were loaded }
  Result := Assigned(_deflateInit_) and
            Assigned(_deflate) and
            Assigned(_deflateEnd) and
            Assigned(_inflateInit_) and
            Assigned(_inflate) and
            Assigned(_inflateEnd);
end;

{$I ../libloaderror.inc}

function LoadZlibLibrary: Boolean;
begin
  if ZlibLibHandle <> NilHandle then
  begin
    Result := True;
    Exit;
  end;

  { Try to load zlib-ng first (native API), then compat mode, then standard zlib }
  ZlibLibHandle := LoadLibrary(ZLIB_LIB_NG);
  if ZlibLibHandle <> NilHandle then
  begin
    UsingZlibNG := True;
    if LoadFunctions then
    begin
      Result := True;
      Exit;
    end;
    FreeLibrary(ZlibLibHandle);
    ZlibLibHandle := NilHandle;
  end;

  { Try compat mode library }
  ZlibLibHandle := LoadLibrary(ZLIB_LIB_COMPAT);
  if ZlibLibHandle <> NilHandle then
  begin
    UsingZlibNG := False;
    if LoadFunctions then
    begin
      Result := True;
      Exit;
    end;
    FreeLibrary(ZlibLibHandle);
    ZlibLibHandle := NilHandle;
  end;

  { Neither the zlib-ng nor the compat name loaded: record why, naming the
    compat library (the one expected to ship beside the program). }
  GZlibLoadError := DescribeLibLoadFailure(ZLIB_LIB_COMPAT);
  Result := False;
  ClearFunctionPointers;
end;

procedure UnloadZlibLibrary;
begin
  if ZlibLibHandle <> NilHandle then
  begin
    FreeLibrary(ZlibLibHandle);
    ZlibLibHandle := NilHandle;
  end;
  UsingZlibNG := False;
  ClearFunctionPointers;
end;

function IsZlibLibraryLoaded: Boolean;
begin
  Result := ZlibLibHandle <> NilHandle;
end;

function GetZlibVersion: string;
begin
  if Assigned(_zlibVersion) then
    Result := string(_zlibVersion)
  else
    Result := '';
end;

function IsZlibNG: Boolean;
begin
  Result := UsingZlibNG;
end;

{ Wrapper functions }

function zlibVersion: PAnsiChar; cdecl;
begin
  if Assigned(_zlibVersion) then
    Result := _zlibVersion
  else
    Result := ZLIB_VERSION;
end;


function deflateInit_(var strm: z_stream; level: Integer;
  const version: PAnsiChar; stream_size: Integer): Integer; cdecl;
begin
  if Assigned(_deflateInit_) then
    Result := _deflateInit_(strm, level, version, stream_size)
  else
    Result := Z_VERSION_ERROR;
end;

function deflate(var strm: z_stream; flush: Integer): Integer; cdecl;
begin
  if Assigned(_deflate) then
    Result := _deflate(strm, flush)
  else
    Result := Z_STREAM_ERROR;
end;

function deflateEnd(var strm: z_stream): Integer; cdecl;
begin
  if Assigned(_deflateEnd) then
    Result := _deflateEnd(strm)
  else
    Result := Z_STREAM_ERROR;
end;

function inflateInit_(var strm: z_stream;
  const version: PAnsiChar; stream_size: Integer): Integer; cdecl;
begin
  if Assigned(_inflateInit_) then
    Result := _inflateInit_(strm, version, stream_size)
  else
    Result := Z_VERSION_ERROR;
end;

function inflate(var strm: z_stream; flush: Integer): Integer; cdecl;
begin
  if Assigned(_inflate) then
    Result := _inflate(strm, flush)
  else
    Result := Z_STREAM_ERROR;
end;

function inflateEnd(var strm: z_stream): Integer; cdecl;
begin
  if Assigned(_inflateEnd) then
    Result := _inflateEnd(strm)
  else
    Result := Z_STREAM_ERROR;
end;

function deflateInit2_(var strm: z_stream; level, method, windowBits,
  memLevel, strategy: Integer; const version: PAnsiChar;
  stream_size: Integer): Integer; cdecl;
begin
  if Assigned(_deflateInit2_) then
    Result := _deflateInit2_(strm, level, method, windowBits, memLevel,
      strategy, version, stream_size)
  else
    Result := Z_VERSION_ERROR;
end;

function deflateSetDictionary(var strm: z_stream; const dictionary: pBytef;
  dictLength: uInt): Integer; cdecl;
begin
  if Assigned(_deflateSetDictionary) then
    Result := _deflateSetDictionary(strm, dictionary, dictLength)
  else
    Result := Z_STREAM_ERROR;
end;

function deflateCopy(var dest, source: z_stream): Integer; cdecl;
begin
  if Assigned(_deflateCopy) then
    Result := _deflateCopy(dest, source)
  else
    Result := Z_STREAM_ERROR;
end;

function deflateReset(var strm: z_stream): Integer; cdecl;
begin
  if Assigned(_deflateReset) then
    Result := _deflateReset(strm)
  else
    Result := Z_STREAM_ERROR;
end;

function deflateParams(var strm: z_stream; level, strategy: Integer): Integer; cdecl;
begin
  if Assigned(_deflateParams) then
    Result := _deflateParams(strm, level, strategy)
  else
    Result := Z_STREAM_ERROR;
end;

function deflateTune(var strm: z_stream; good_length, max_lazy,
  nice_length, max_chain: Integer): Integer; cdecl;
begin
  if Assigned(_deflateTune) then
    Result := _deflateTune(strm, good_length, max_lazy, nice_length, max_chain)
  else
    Result := Z_STREAM_ERROR;
end;

function deflateBound(var strm: z_stream; sourceLen: uLong): uLong; cdecl;
begin
  if Assigned(_deflateBound) then
    Result := _deflateBound(strm, sourceLen)
  else
    Result := sourceLen + (sourceLen shr 12) + (sourceLen shr 14) +
              (sourceLen shr 25) + 13;
end;

function deflatePrime(var strm: z_stream; bits, value: Integer): Integer; cdecl;
begin
  if Assigned(_deflatePrime) then
    Result := _deflatePrime(strm, bits, value)
  else
    Result := Z_STREAM_ERROR;
end;

function deflateSetHeader(var strm: z_stream; var head: gz_header): Integer; cdecl;
begin
  if Assigned(_deflateSetHeader) then
    Result := _deflateSetHeader(strm, head)
  else
    Result := Z_STREAM_ERROR;
end;

function inflateInit2_(var strm: z_stream; windowBits: Integer;
  const version: PAnsiChar; stream_size: Integer): Integer; cdecl;
begin
  if Assigned(_inflateInit2_) then
    Result := _inflateInit2_(strm, windowBits, version, stream_size)
  else
    Result := Z_VERSION_ERROR;
end;

function inflateSetDictionary(var strm: z_stream; const dictionary: pBytef;
  dictLength: uInt): Integer; cdecl;
begin
  if Assigned(_inflateSetDictionary) then
    Result := _inflateSetDictionary(strm, dictionary, dictLength)
  else
    Result := Z_STREAM_ERROR;
end;

function inflateSync(var strm: z_stream): Integer; cdecl;
begin
  if Assigned(_inflateSync) then
    Result := _inflateSync(strm)
  else
    Result := Z_STREAM_ERROR;
end;

function inflateCopy(var dest, source: z_stream): Integer; cdecl;
begin
  if Assigned(_inflateCopy) then
    Result := _inflateCopy(dest, source)
  else
    Result := Z_STREAM_ERROR;
end;

function inflateReset(var strm: z_stream): Integer; cdecl;
begin
  if Assigned(_inflateReset) then
    Result := _inflateReset(strm)
  else
    Result := Z_STREAM_ERROR;
end;

function inflateReset2(var strm: z_stream; windowBits: Integer): Integer; cdecl;
begin
  if Assigned(_inflateReset2) then
    Result := _inflateReset2(strm, windowBits)
  else
    Result := Z_STREAM_ERROR;
end;

function inflatePrime(var strm: z_stream; bits, value: Integer): Integer; cdecl;
begin
  if Assigned(_inflatePrime) then
    Result := _inflatePrime(strm, bits, value)
  else
    Result := Z_STREAM_ERROR;
end;

function inflateMark(var strm: z_stream): LongInt; cdecl;
begin
  if Assigned(_inflateMark) then
    Result := _inflateMark(strm)
  else
    Result := -(1 shl 16);
end;

function inflateGetHeader(var strm: z_stream; var head: gz_header): Integer; cdecl;
begin
  if Assigned(_inflateGetHeader) then
    Result := _inflateGetHeader(strm, head)
  else
    Result := Z_STREAM_ERROR;
end;

function compress(dest: pBytef; var destLen: uLong;
  const source: pBytef; sourceLen: uLong): Integer; cdecl;
begin
  if Assigned(_compress) then
    Result := _compress(dest, destLen, source, sourceLen)
  else
    Result := Z_STREAM_ERROR;
end;

function compress2(dest: pBytef; var destLen: uLong;
  const source: pBytef; sourceLen: uLong; level: Integer): Integer; cdecl;
begin
  if Assigned(_compress2) then
    Result := _compress2(dest, destLen, source, sourceLen, level)
  else
    Result := Z_STREAM_ERROR;
end;

function compressBound(sourceLen: uLong): uLong; cdecl;
begin
  if Assigned(_compressBound) then
    Result := _compressBound(sourceLen)
  else
    Result := sourceLen + (sourceLen shr 12) + (sourceLen shr 14) +
              (sourceLen shr 25) + 13;
end;

function uncompress(dest: pBytef; var destLen: uLong;
  const source: pBytef; sourceLen: uLong): Integer; cdecl;
begin
  if Assigned(_uncompress) then
    Result := _uncompress(dest, destLen, source, sourceLen)
  else
    Result := Z_STREAM_ERROR;
end;

function adler32(adler: uLong; const buf: pBytef; len: uInt): uLong; cdecl;
begin
  if Assigned(_adler32) then
    Result := _adler32(adler, buf, len)
  else
    Result := 1;
end;

function adler32_combine(adler1, adler2: uLong; len2: LongInt): uLong; cdecl;
begin
  if Assigned(_adler32_combine) then
    Result := _adler32_combine(adler1, adler2, len2)
  else
    Result := 0;
end;

function crc32(crc: uLong; const buf: pBytef; len: uInt): uLong; cdecl;
begin
  if Assigned(_crc32) then
    Result := _crc32(crc, buf, len)
  else
    Result := 0;
end;

function crc32_combine(crc1, crc2: uLong; len2: LongInt): uLong; cdecl;
begin
  if Assigned(_crc32_combine) then
    Result := _crc32_combine(crc1, crc2, len2)
  else
    Result := 0;
end;

{ Helper functions (macros) }

function deflateInit(var strm: z_stream; level: Integer): Integer;
begin
  Result := deflateInit_(strm, level, ZLIB_VERSION, SizeOf(z_stream));
end;

function inflateInit(var strm: z_stream): Integer;
begin
  Result := inflateInit_(strm, ZLIB_VERSION, SizeOf(z_stream));
end;

function deflateInit2(var strm: z_stream; level, method, windowBits,
  memLevel, strategy: Integer): Integer;
begin
  Result := deflateInit2_(strm, level, method, windowBits, memLevel,
    strategy, ZLIB_VERSION, SizeOf(z_stream));
end;

function inflateInit2(var strm: z_stream; windowBits: Integer): Integer;
begin
  Result := inflateInit2_(strm, windowBits, ZLIB_VERSION, SizeOf(z_stream));
end;

function ZlibLoadError: string;
begin
  Result := GZlibLoadError;
end;

initialization
  LoadZlibLibrary;

finalization
  UnloadZlibLibrary;


end.
