{*******************************************************}
{                                                       }
{       ZLIB Data Compression Interface Unit            }
{       (named dzlib before 2026-08-24 - renamed to      }
{        match upstream galfar/imaginglib 5424472)       }
{       Modified for Vampyre Imaging Library            }
{       FreePascal-only fork with zlib-ng support       }
{                                                       }
{*******************************************************}

{
  This unit provides zlib compression/decompression functionality.

  Implementation options:
  - ZLIBNG_EXTERNAL: Use external zlib-ng/zlib library (default, fastest)
  - FPCPASZLIB: Use FPC's built-in paszlib (fallback)
}

unit ImagingZLib;

{$I ..\ImagingOptions.inc}

interface

{ Default: Use external zlib-ng/zlib library for best performance.
  Define FPCPASZLIB to use FPC's built-in paszlib as fallback. }
{$DEFINE ZLIBNG_EXTERNAL}
{ $DEFINE FPCPASZLIB}

uses
{$IF Defined(ZLIBNG_EXTERNAL)}
  zlibng_bindings,
{$ELSEIF Defined(FPCPASZLIB)}
  zbase, paszlib,
{$IFEND}
  ImagingTypes, SysUtils, Classes;

{$IF Defined(FPCPASZLIB)}
type
  TZStreamRec = z_stream;
{$IFEND}

const
  Z_NO_FLUSH      = 0;
  Z_PARTIAL_FLUSH = 1;
  Z_SYNC_FLUSH    = 2;
  Z_FULL_FLUSH    = 3;
  Z_FINISH        = 4;

  Z_OK            =  0;
  Z_STREAM_END    =  1;
  Z_NEED_DICT     =  2;
  Z_ERRNO         = -1;
  Z_STREAM_ERROR  = -2;
  Z_DATA_ERROR    = -3;
  Z_MEM_ERROR     = -4;
  Z_BUF_ERROR     = -5;
  Z_VERSION_ERROR = -6;

  Z_NO_COMPRESSION       =  0;
  Z_BEST_SPEED           =  1;
  Z_BEST_COMPRESSION     =  9;
  Z_DEFAULT_COMPRESSION  = -1;

  Z_FILTERED            = 1;
  Z_HUFFMAN_ONLY        = 2;
  Z_RLE                 = 3;
  Z_DEFAULT_STRATEGY    = 0;

  Z_BINARY   = 0;
  Z_ASCII    = 1;
  Z_UNKNOWN  = 2;

  Z_DEFLATED = 8;

type
  { Abstract ancestor class }
  TCustomZlibStream = class(TStream)
  private
    FStrm: TStream;
    FStrmPos: Integer;
    FOnProgress: TNotifyEvent;
    FZRec: TZStreamRec;
    FBuffer: array [Word] of Byte;
  protected
    procedure Progress(Sender: TObject); dynamic;
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
    constructor Create(Strm: TStream);
  end;

  TCompressionLevel = (clNone, clFastest, clDefault, clMax);

  TCompressionStream = class(TCustomZlibStream)
  private
    function GetCompressionRate: Single;
  public
    constructor Create(CompressionLevel: TCompressionLevel; Dest: TStream);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    property CompressionRate: Single read GetCompressionRate;
    property OnProgress;
  end;

  TDecompressionStream = class(TCustomZlibStream)
  public
    constructor Create(Source: TStream);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    property OnProgress;
  end;

procedure CompressBuf(const InBuf: Pointer; InBytes: Integer;
  var OutBuf: Pointer; var OutBytes: Integer;
  CompressLevel: Integer = Z_DEFAULT_COMPRESSION;
  CompressStrategy: Integer = Z_DEFAULT_STRATEGY);

procedure DecompressBuf(const InBuf: Pointer; InBytes: Integer;
 OutEstimate: Integer; var OutBuf: Pointer; var OutBytes: Integer);

type
  EZlibError = class(Exception);
  ECompressionError = class(EZlibError);
  EDecompressionError = class(EZlibError);

implementation

const
  ZErrorMessages: array[0..9] of PAnsiChar = (
    'need dictionary',
    'stream end',
    '',
    'file error',
    'stream error',
    'data error',
    'insufficient memory',
    'buffer error',
    'incompatible version',
    '');

function zlibAllocMem(AppData: Pointer; Items, Size: Cardinal): Pointer; cdecl;
begin
  GetMem(Result, Items*Size);
end;

procedure zlibFreeMem(AppData, Block: Pointer); cdecl;
begin
  FreeMem(Block);
end;

function CCheck(code: Integer): Integer;
begin
  Result := code;
  if code < 0 then
    raise ECompressionError.Create('zlib: ' + string(ZErrorMessages[2 - code]));
end;

function DCheck(code: Integer): Integer;
begin
  Result := code;
  if code < 0 then
    raise EDecompressionError.Create('zlib: ' + string(ZErrorMessages[2 - code]));
end;

procedure CompressBuf(const InBuf: Pointer; InBytes: Integer;
  var OutBuf: Pointer; var OutBytes: Integer;
  CompressLevel, CompressStrategy: Integer);
var
  strm: TZStreamRec;
  P: Pointer;
begin
  FillChar(strm, sizeof(strm), 0);
{$IFDEF ZLIBNG_EXTERNAL}
  strm.zalloc := @zlibAllocMem;
  strm.zfree := @zlibFreeMem;
{$ENDIF}
  OutBytes := ((InBytes + (InBytes div 10) + 12) + 255) and not 255;
  GetMem(OutBuf, OutBytes);
  try
    strm.next_in := InBuf;
    strm.avail_in := InBytes;
    strm.next_out := OutBuf;
    strm.avail_out := OutBytes;

    CCheck(deflateInit2_(strm, CompressLevel, Z_DEFLATED, MAX_WBITS,
      DEF_MEM_LEVEL, CompressStrategy, zlib_version, sizeof(strm)));

    try
      while CCheck(deflate(strm, Z_FINISH)) <> Z_STREAM_END do
      begin
        P := OutBuf;
        Inc(OutBytes, 256);
        ReallocMem(OutBuf, OutBytes);
        strm.next_out := Pointer(PtrUInt(OutBuf) + (PtrUInt(strm.next_out) - PtrUInt(P)));
        strm.avail_out := 256;
      end;
    finally
      CCheck(deflateEnd(strm));
    end;
    ReallocMem(OutBuf, strm.total_out);
    OutBytes := strm.total_out;
  except
    zlibFreeMem(nil, OutBuf);
    raise
  end;
end;

procedure DecompressBuf(const InBuf: Pointer; InBytes: Integer;
 OutEstimate: Integer; var OutBuf: Pointer; var OutBytes: Integer);
var
  strm: TZStreamRec;
  P: Pointer;
  BufInc: Integer;
begin
  FillChar(strm, sizeof(strm), 0);
{$IFDEF ZLIBNG_EXTERNAL}
  strm.zalloc := @zlibAllocMem;
  strm.zfree := @zlibFreeMem;
{$ENDIF}
  BufInc := (InBytes + 255) and not 255;
  if OutEstimate = 0 then
    OutBytes := BufInc
  else
    OutBytes := OutEstimate;
  GetMem(OutBuf, OutBytes);
  try
    strm.next_in := InBuf;
    strm.avail_in := InBytes;
    strm.next_out := OutBuf;
    strm.avail_out := OutBytes;
    DCheck(inflateInit_(strm, zlib_version, sizeof(strm)));
    try
      while DCheck(inflate(strm, Z_NO_FLUSH)) <> Z_STREAM_END do
      begin
        P := OutBuf;
        Inc(OutBytes, BufInc);
        ReallocMem(OutBuf, OutBytes);
        strm.next_out := Pointer(PtrUInt(OutBuf) + (PtrUInt(strm.next_out) - PtrUInt(P)));
        strm.avail_out := BufInc;
      end;
    finally
      DCheck(inflateEnd(strm));
    end;
    ReallocMem(OutBuf, strm.total_out);
    OutBytes := strm.total_out;
  except
    zlibFreeMem(nil, OutBuf);
    raise
  end;
end;

{ TCustomZlibStream }

constructor TCustomZLibStream.Create(Strm: TStream);
begin
  inherited Create;
  FStrm := Strm;
  FStrmPos := Strm.Position;
{$IFDEF ZLIBNG_EXTERNAL}
  FZRec.zalloc := @zlibAllocMem;
  FZRec.zfree := @zlibFreeMem;
{$ENDIF}
end;

procedure TCustomZLibStream.Progress(Sender: TObject);
begin
  if Assigned(FOnProgress) then FOnProgress(Sender);
end;

{ TCompressionStream }

constructor TCompressionStream.Create(CompressionLevel: TCompressionLevel;
  Dest: TStream);
const
  Levels: array [TCompressionLevel] of ShortInt =
    (Z_NO_COMPRESSION, Z_BEST_SPEED, Z_DEFAULT_COMPRESSION, Z_BEST_COMPRESSION);
begin
  inherited Create(Dest);
  FZRec.next_out := @FBuffer;
  FZRec.avail_out := sizeof(FBuffer);
  CCheck(deflateInit_(FZRec, Levels[CompressionLevel], zlib_version, sizeof(FZRec)));
end;

destructor TCompressionStream.Destroy;
begin
  FZRec.next_in := nil;
  FZRec.avail_in := 0;
  try
    if FStrm.Position <> FStrmPos then FStrm.Position := FStrmPos;
    while (CCheck(deflate(FZRec, Z_FINISH)) <> Z_STREAM_END)
      and (FZRec.avail_out = 0) do
    begin
      FStrm.WriteBuffer(FBuffer, sizeof(FBuffer));
      FZRec.next_out := @FBuffer;
      FZRec.avail_out := sizeof(FBuffer);
    end;
    if FZRec.avail_out < sizeof(FBuffer) then
      FStrm.WriteBuffer(FBuffer, sizeof(FBuffer) - FZRec.avail_out);
  finally
    deflateEnd(FZRec);
  end;
  inherited Destroy;
end;

function TCompressionStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := 0;
  raise ECompressionError.Create('Invalid stream operation');
end;

function TCompressionStream.Write(const Buffer; Count: Longint): Longint;
begin
  FZRec.next_in := @Buffer;
  FZRec.avail_in := Count;
  if FStrm.Position <> FStrmPos then FStrm.Position := FStrmPos;
  while (FZRec.avail_in > 0) do
  begin
    CCheck(deflate(FZRec, 0));
    if FZRec.avail_out = 0 then
    begin
      FStrm.WriteBuffer(FBuffer, sizeof(FBuffer));
      FZRec.next_out := @FBuffer;
      FZRec.avail_out := sizeof(FBuffer);
      FStrmPos := FStrm.Position;
      Progress(Self);
    end;
  end;
  Result := Count;
end;

function TCompressionStream.Seek(Offset: Longint; Origin: Word): Longint;
begin
  if (Offset = 0) and (Origin = soFromCurrent) then
    Result := FZRec.total_in
  else
    raise ECompressionError.Create('Invalid stream operation');
end;

function TCompressionStream.GetCompressionRate: Single;
begin
  if FZRec.total_in = 0 then
    Result := 0
  else
    Result := (1.0 - (FZRec.total_out / FZRec.total_in)) * 100.0;
end;

{ TDecompressionStream }

constructor TDecompressionStream.Create(Source: TStream);
begin
  inherited Create(Source);
  FZRec.next_in := @FBuffer;
  FZRec.avail_in := 0;
  DCheck(inflateInit_(FZRec, zlib_version, sizeof(FZRec)));
end;

destructor TDecompressionStream.Destroy;
begin
  inflateEnd(FZRec);
  inherited Destroy;
end;

function TDecompressionStream.Read(var Buffer; Count: Longint): Longint;
begin
  FZRec.next_out := @Buffer;
  FZRec.avail_out := Count;
  if FStrm.Position <> FStrmPos then FStrm.Position := FStrmPos;
  while (FZRec.avail_out > 0) do
  begin
    if FZRec.avail_in = 0 then
    begin
      FZRec.avail_in := FStrm.Read(FBuffer, sizeof(FBuffer));
      if FZRec.avail_in = 0 then
        begin
          Result := Count - Integer(FZRec.avail_out);
          Exit;
        end;
      FZRec.next_in := @FBuffer;
      FStrmPos := FStrm.Position;
      Progress(Self);
    end;
    CCheck(inflate(FZRec, 0));
  end;
  Result := Count;
end;

function TDecompressionStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := 0;
  raise EDecompressionError.Create('Invalid stream operation');
end;

function TDecompressionStream.Seek(Offset: Longint; Origin: Word): Longint;
var
  I: Integer;
  Buf: array [0..4095] of Byte;
begin
  if (Offset = 0) and (Origin = soFromBeginning) then
  begin
    DCheck(inflateReset(FZRec));
    FZRec.next_in := @FBuffer;
    FZRec.avail_in := 0;
    FStrm.Position := 0;
    FStrmPos := 0;
  end
  else if ( (Offset >= 0) and (Origin = soFromCurrent)) or
          ( ((Offset - Integer(FZRec.total_out)) > 0) and (Origin = soFromBeginning)) then
  begin
    if Origin = soFromBeginning then Dec(Offset, FZRec.total_out);
    if Offset > 0 then
    begin
      for I := 1 to Offset div sizeof(Buf) do
        ReadBuffer(Buf, sizeof(Buf));
      ReadBuffer(Buf, Offset mod sizeof(Buf));
    end;
  end
  else
    raise EDecompressionError.Create('Invalid stream operation');
  Result := FZRec.total_out;
end;

end.
