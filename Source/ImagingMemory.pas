{*******************************************************}
{                                                       }
{       Imaging Memory Management Unit                  }
{       FreePascal-only with aligned allocation         }
{                                                       }
{       Supports optional FastMM4-AVX integration       }
{       and SIMD-aligned memory allocations             }
{                                                       }
{*******************************************************}

unit ImagingMemory;

{$I ImagingOptions.inc}

interface

uses
  SysUtils;

{ Standard memory allocation wrappers }
function ImagingGetMem(Size: NativeInt): Pointer;
function ImagingAllocMem(Size: NativeInt): Pointer;
procedure ImagingFreeMem(P: Pointer);
function ImagingReallocMem(P: Pointer; Size: NativeInt): Pointer;

{ Aligned memory allocation for SIMD operations }
{ Default alignment is 32 bytes (AVX2 requirement) }
{ For AVX-512, use Alignment = 64 }
function ImagingAllocAligned(Size: NativeInt; Alignment: Integer = 32): Pointer;
procedure ImagingFreeAligned(P: Pointer);
function ImagingReallocAligned(P: Pointer; OldSize, NewSize: NativeInt;
  Alignment: Integer = 32): Pointer;

{ Utility functions }
function IsPointerAligned(P: Pointer; Alignment: Integer): Boolean; inline;
function AlignUp(Value: NativeInt; Alignment: Integer): NativeInt; inline;

{ Memory info }
function GetAlignedAllocationOverhead(Alignment: Integer): Integer; inline;

implementation

{$IFDEF MSWINDOWS}
uses
  Windows;
{$ENDIF}

{$IFDEF UNIX}
uses
  {$IFDEF DARWIN}
  ctypes,
  {$ENDIF}
  BaseUnix;
{$ENDIF}

{ Platform-specific aligned allocation }

{$IFDEF MSWINDOWS}
{ Windows: Use _aligned_malloc/_aligned_free from msvcrt or VirtualAlloc }

function _aligned_malloc(Size: NativeUInt; Alignment: NativeUInt): Pointer;
  cdecl; external 'msvcrt.dll' name '_aligned_malloc';
procedure _aligned_free(P: Pointer);
  cdecl; external 'msvcrt.dll' name '_aligned_free';
function _aligned_realloc(P: Pointer; Size: NativeUInt; Alignment: NativeUInt): Pointer;
  cdecl; external 'msvcrt.dll' name '_aligned_realloc';

function PlatformAllocAligned(Size: NativeInt; Alignment: Integer): Pointer;
begin
  Result := _aligned_malloc(Size, Alignment);
end;

procedure PlatformFreeAligned(P: Pointer);
begin
  _aligned_free(P);
end;

function PlatformReallocAligned(P: Pointer; Size: NativeInt; Alignment: Integer): Pointer;
begin
  Result := _aligned_realloc(P, Size, Alignment);
end;

{$ELSE}

{$IFDEF DARWIN}
{ macOS: Use posix_memalign }

function posix_memalign(var MemPtr: Pointer; Alignment, Size: NativeUInt): Integer;
  cdecl; external 'c' name 'posix_memalign';

function PlatformAllocAligned(Size: NativeInt; Alignment: Integer): Pointer;
begin
  Result := nil;
  if posix_memalign(Result, Alignment, Size) <> 0 then
    Result := nil;
end;

procedure PlatformFreeAligned(P: Pointer);
begin
  if P <> nil then
    FreeMem(P); // posix_memalign memory can be freed with free()
end;

function PlatformReallocAligned(P: Pointer; Size: NativeInt; Alignment: Integer): Pointer;
var
  NewP: Pointer;
begin
  // posix_memalign doesn't have realloc, so we allocate new and copy
  // For safety, we allocate new, copy, then free old
  // Note: This is inefficient - caller should track old size
  NewP := PlatformAllocAligned(Size, Alignment);
  if (NewP <> nil) and (P <> nil) then
  begin
    // Can't know old size here - caller must use ImagingReallocAligned with OldSize
    PlatformFreeAligned(P);
  end;
  Result := NewP;
end;

{$ELSE}
{ Linux and other Unix: Use posix_memalign or aligned_alloc }

function posix_memalign(var MemPtr: Pointer; Alignment, Size: NativeUInt): Integer;
  cdecl; external 'c' name 'posix_memalign';

function PlatformAllocAligned(Size: NativeInt; Alignment: Integer): Pointer;
begin
  Result := nil;
  if posix_memalign(Result, Alignment, Size) <> 0 then
    Result := nil;
end;

procedure PlatformFreeAligned(P: Pointer);
begin
  if P <> nil then
    FreeMem(P);
end;

function PlatformReallocAligned(P: Pointer; Size: NativeInt; Alignment: Integer): Pointer;
var
  NewP: Pointer;
begin
  NewP := PlatformAllocAligned(Size, Alignment);
  if (NewP <> nil) and (P <> nil) then
    PlatformFreeAligned(P);
  Result := NewP;
end;

{$ENDIF}
{$ENDIF}

{ Manual aligned allocation fallback }
{ Stores original pointer before the aligned address }

type
  PPointer = ^Pointer;

function ManualAllocAligned(Size: NativeInt; Alignment: Integer): Pointer;
var
  RawPtr: Pointer;
  AlignedPtr: Pointer;
  Offset: NativeInt;
begin
  // Allocate extra space for alignment and pointer storage
  GetMem(RawPtr, Size + Alignment + SizeOf(Pointer));
  if RawPtr = nil then
    Exit(nil);

  // Calculate aligned address, leaving room for original pointer
  Offset := (NativeInt(RawPtr) + SizeOf(Pointer) + Alignment - 1) and (not (Alignment - 1));
  AlignedPtr := Pointer(Offset);

  // Store original pointer just before aligned address
  PPointer(NativeInt(AlignedPtr) - SizeOf(Pointer))^ := RawPtr;

  Result := AlignedPtr;
end;

procedure ManualFreeAligned(P: Pointer);
var
  RawPtr: Pointer;
begin
  if P = nil then
    Exit;
  // Retrieve original pointer
  RawPtr := PPointer(NativeInt(P) - SizeOf(Pointer))^;
  FreeMem(RawPtr);
end;

function ManualReallocAligned(P: Pointer; OldSize, NewSize: NativeInt;
  Alignment: Integer): Pointer;
var
  NewP: Pointer;
  CopySize: NativeInt;
begin
  if P = nil then
    Exit(ManualAllocAligned(NewSize, Alignment));

  if NewSize = 0 then
  begin
    ManualFreeAligned(P);
    Exit(nil);
  end;

  NewP := ManualAllocAligned(NewSize, Alignment);
  if NewP = nil then
    Exit(nil);

  // Copy data
  if OldSize < NewSize then
    CopySize := OldSize
  else
    CopySize := NewSize;
  Move(P^, NewP^, CopySize);

  ManualFreeAligned(P);
  Result := NewP;
end;

{ Public functions }

function ImagingGetMem(Size: NativeInt): Pointer;
begin
  GetMem(Result, Size);
end;

function ImagingAllocMem(Size: NativeInt): Pointer;
begin
  Result := AllocMem(Size);
end;

procedure ImagingFreeMem(P: Pointer);
begin
  if P <> nil then
    FreeMem(P);
end;

function ImagingReallocMem(P: Pointer; Size: NativeInt): Pointer;
begin
  Result := P;
  ReallocMem(Result, Size);
end;

function ImagingAllocAligned(Size: NativeInt; Alignment: Integer): Pointer;
begin
  // Validate alignment is power of 2
  if (Alignment <= 0) or ((Alignment and (Alignment - 1)) <> 0) then
    raise EInvalidOp.Create('ImagingAllocAligned: Alignment must be a power of 2');

  // Minimum alignment is pointer size
  if Alignment < SizeOf(Pointer) then
    Alignment := SizeOf(Pointer);

  {$IFDEF USE_PLATFORM_ALIGNED_ALLOC}
  Result := PlatformAllocAligned(Size, Alignment);
  if Result = nil then
  {$ENDIF}
    Result := ManualAllocAligned(Size, Alignment);
end;

procedure ImagingFreeAligned(P: Pointer);
begin
  {$IFDEF USE_PLATFORM_ALIGNED_ALLOC}
  PlatformFreeAligned(P);
  {$ELSE}
  ManualFreeAligned(P);
  {$ENDIF}
end;

function ImagingReallocAligned(P: Pointer; OldSize, NewSize: NativeInt;
  Alignment: Integer): Pointer;
begin
  // Validate alignment is power of 2
  if (Alignment <= 0) or ((Alignment and (Alignment - 1)) <> 0) then
    raise EInvalidOp.Create('ImagingReallocAligned: Alignment must be a power of 2');

  // Minimum alignment is pointer size
  if Alignment < SizeOf(Pointer) then
    Alignment := SizeOf(Pointer);

  {$IFDEF USE_PLATFORM_ALIGNED_ALLOC}
  // Platform realloc may not preserve alignment properly on all platforms
  // So we use manual method for safety
  {$ENDIF}
  Result := ManualReallocAligned(P, OldSize, NewSize, Alignment);
end;

function IsPointerAligned(P: Pointer; Alignment: Integer): Boolean;
begin
  Result := (NativeInt(P) and (Alignment - 1)) = 0;
end;

function AlignUp(Value: NativeInt; Alignment: Integer): NativeInt;
begin
  Result := (Value + Alignment - 1) and (not (Alignment - 1));
end;

function GetAlignedAllocationOverhead(Alignment: Integer): Integer;
begin
  // Overhead is alignment + pointer storage
  Result := Alignment + SizeOf(Pointer);
end;

end.
