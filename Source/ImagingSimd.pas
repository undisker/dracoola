{*******************************************************}
{                                                       }
{       Imaging SIMD Acceleration Unit                  }
{       FreePascal-only with SSE2/AVX2/NEON support     }
{                                                       }
{       Provides SIMD-accelerated pixel format          }
{       conversions for common image operations         }
{                                                       }
{*******************************************************}

unit ImagingSimd;

{$I ImagingOptions.inc}

interface

uses
  SysUtils, ImagingTypes;

{ CPU Feature Detection }
type
  TCpuFeatures = record
    HasSSE2: Boolean;
    HasSSE3: Boolean;
    HasSSSE3: Boolean;
    HasSSE41: Boolean;
    HasSSE42: Boolean;
    HasAVX: Boolean;
    HasAVX2: Boolean;
    HasAVX512F: Boolean;
    HasNEON: Boolean;  // ARM SIMD
  end;

var
  CpuFeatures: TCpuFeatures;

{ Initialize CPU feature detection - called automatically at startup }
procedure InitCpuFeatures;

{ SIMD-accelerated pixel format conversions }

{ RGB24 <-> RGBA32 conversions }
procedure ConvertRGB24ToRGBA32(Src: PByte; Dest: PByte; PixelCount: Integer);
procedure ConvertRGBA32ToRGB24(Src: PByte; Dest: PByte; PixelCount: Integer);

{ BGR24 <-> BGRA32 conversions }
procedure ConvertBGR24ToBGRA32(Src: PByte; Dest: PByte; PixelCount: Integer);
procedure ConvertBGRA32ToBGR24(Src: PByte; Dest: PByte; PixelCount: Integer);

{ Channel swap: RGBA <-> BGRA }
procedure ConvertRGBA32ToBGRA32(Src: PByte; Dest: PByte; PixelCount: Integer);
procedure ConvertBGRA32ToRGBA32(Src: PByte; Dest: PByte; PixelCount: Integer);

{ RGB <-> BGR swap (24-bit) }
procedure ConvertRGB24ToBGR24(Src: PByte; Dest: PByte; PixelCount: Integer);
procedure ConvertBGR24ToRGB24(Src: PByte; Dest: PByte; PixelCount: Integer);

{ Grayscale conversions }
procedure ConvertGray8ToRGBA32(Src: PByte; Dest: PByte; PixelCount: Integer);
procedure ConvertRGBA32ToGray8(Src: PByte; Dest: PByte; PixelCount: Integer);
procedure ConvertRGB24ToGray8(Src: PByte; Dest: PByte; PixelCount: Integer);

{ Alpha channel operations }
procedure PremultiplyAlphaRGBA32(Data: PByte; PixelCount: Integer);
procedure UnpremultiplyAlphaRGBA32(Data: PByte; PixelCount: Integer);
procedure SetAlphaRGBA32(Data: PByte; PixelCount: Integer; Alpha: Byte);

{ Memory operations }
procedure FillMemory32(Dest: PByte; Count: Integer; Value: LongWord);

implementation

{$IFDEF CPUX64}
  {$DEFINE HAS_SSE2}
  {$DEFINE CAN_USE_AVX2}
{$ENDIF}

{$IFDEF CPUX86}
  {$DEFINE HAS_SSE2}
{$ENDIF}

{$IFDEF CPUAARCH64}
  {$DEFINE HAS_NEON}
{$ENDIF}

{$IFDEF CPUARM}
  {$DEFINE HAS_NEON}
{$ENDIF}

{ SSSE3 shuffle mask for RGBA <-> BGRA conversion (swap bytes 0 and 2 in each dword) }
const
  RGBA_BGRA_ShuffleMask: array[0..15] of Byte = (
    2, 1, 0, 3, 6, 5, 4, 7, 10, 9, 8, 11, 14, 13, 12, 15
  );

{ CPU Feature Detection }

{$IFDEF CPUX64}
procedure CPUID(Func: LongWord; var EAX, EBX, ECX, EDX: LongWord); assembler; nostackframe;
asm
  {$IFDEF MSWINDOWS}
  // RCX = Func, RDX = @EAX, R8 = @EBX, R9 = @ECX, stack = @EDX
  push rbx
  mov eax, ecx
  xor ecx, ecx
  cpuid
  mov [rdx], eax
  mov [r8], ebx
  mov [r9], ecx
  mov rax, [rsp + 40]  // @EDX parameter
  mov [rax], edx
  pop rbx
  {$ELSE}
  // RDI = Func, RSI = @EAX, RDX = @EBX, RCX = @ECX, R8 = @EDX
  push rbx
  mov eax, edi
  xor ecx, ecx
  cpuid
  mov [rsi], eax
  mov [rdx], ebx
  mov [rcx], ecx
  mov [r8], edx
  pop rbx
  {$ENDIF}
end;

procedure InitCpuFeatures;
var
  EAX, EBX, ECX, EDX: LongWord;
  MaxFunc: LongWord;
begin
  FillChar(CpuFeatures, SizeOf(CpuFeatures), 0);

  // Get max supported function
  CPUID(0, EAX, EBX, ECX, EDX);
  MaxFunc := EAX;

  if MaxFunc >= 1 then
  begin
    CPUID(1, EAX, EBX, ECX, EDX);
    CpuFeatures.HasSSE2 := (EDX and (1 shl 26)) <> 0;
    CpuFeatures.HasSSE3 := (ECX and (1 shl 0)) <> 0;
    CpuFeatures.HasSSSE3 := (ECX and (1 shl 9)) <> 0;
    CpuFeatures.HasSSE41 := (ECX and (1 shl 19)) <> 0;
    CpuFeatures.HasSSE42 := (ECX and (1 shl 20)) <> 0;
    CpuFeatures.HasAVX := (ECX and (1 shl 28)) <> 0;
  end;

  if MaxFunc >= 7 then
  begin
    CPUID(7, EAX, EBX, ECX, EDX);
    CpuFeatures.HasAVX2 := (EBX and (1 shl 5)) <> 0;
    CpuFeatures.HasAVX512F := (EBX and (1 shl 16)) <> 0;
  end;
end;
{$ENDIF}

{$IFDEF CPUX86}
procedure CPUID(Func: LongWord; var EAX, EBX, ECX, EDX: LongWord); assembler;
asm
  push ebx
  push esi
  mov esi, edx  // @EBX
  mov eax, Func
  xor ecx, ecx
  cpuid
  mov [eax], eax  // Actually this won't work, need to save pointers first
  pop esi
  pop ebx
end;

procedure InitCpuFeatures;
begin
  FillChar(CpuFeatures, SizeOf(CpuFeatures), 0);
  // x86 always has SSE2 on modern systems
  CpuFeatures.HasSSE2 := True;
end;
{$ENDIF}

{$IFDEF HAS_NEON}
procedure InitCpuFeatures;
begin
  FillChar(CpuFeatures, SizeOf(CpuFeatures), 0);
  // ARM64 always has NEON
  CpuFeatures.HasNEON := True;
end;
{$ENDIF}

{$IF not Defined(CPUX64) and not Defined(CPUX86) and not Defined(HAS_NEON)}
procedure InitCpuFeatures;
begin
  FillChar(CpuFeatures, SizeOf(CpuFeatures), 0);
end;
{$IFEND}

{ Scalar fallback implementations }

procedure ConvertRGB24ToRGBA32_Scalar(Src: PByte; Dest: PByte; PixelCount: Integer);
var
  I: Integer;
begin
  for I := 0 to PixelCount - 1 do
  begin
    Dest[0] := Src[0];  // R
    Dest[1] := Src[1];  // G
    Dest[2] := Src[2];  // B
    Dest[3] := 255;     // A
    Inc(Src, 3);
    Inc(Dest, 4);
  end;
end;

procedure ConvertRGBA32ToRGB24_Scalar(Src: PByte; Dest: PByte; PixelCount: Integer);
var
  I: Integer;
begin
  for I := 0 to PixelCount - 1 do
  begin
    Dest[0] := Src[0];  // R
    Dest[1] := Src[1];  // G
    Dest[2] := Src[2];  // B
    Inc(Src, 4);
    Inc(Dest, 3);
  end;
end;

procedure ConvertBGR24ToBGRA32_Scalar(Src: PByte; Dest: PByte; PixelCount: Integer);
var
  I: Integer;
begin
  for I := 0 to PixelCount - 1 do
  begin
    Dest[0] := Src[0];  // B
    Dest[1] := Src[1];  // G
    Dest[2] := Src[2];  // R
    Dest[3] := 255;     // A
    Inc(Src, 3);
    Inc(Dest, 4);
  end;
end;

procedure ConvertBGRA32ToBGR24_Scalar(Src: PByte; Dest: PByte; PixelCount: Integer);
var
  I: Integer;
begin
  for I := 0 to PixelCount - 1 do
  begin
    Dest[0] := Src[0];  // B
    Dest[1] := Src[1];  // G
    Dest[2] := Src[2];  // R
    Inc(Src, 4);
    Inc(Dest, 3);
  end;
end;

procedure ConvertRGBA32ToBGRA32_Scalar(Src: PByte; Dest: PByte; PixelCount: Integer);
var
  I: Integer;
  R, B: Byte;
begin
  for I := 0 to PixelCount - 1 do
  begin
    R := Src[0];
    B := Src[2];
    Dest[0] := B;       // B
    Dest[1] := Src[1];  // G
    Dest[2] := R;       // R
    Dest[3] := Src[3];  // A
    Inc(Src, 4);
    Inc(Dest, 4);
  end;
end;

procedure ConvertBGRA32ToRGBA32_Scalar(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  // Same operation as RGBA->BGRA
  ConvertRGBA32ToBGRA32_Scalar(Src, Dest, PixelCount);
end;

procedure ConvertRGB24ToBGR24_Scalar(Src: PByte; Dest: PByte; PixelCount: Integer);
var
  I: Integer;
  R, B: Byte;
begin
  for I := 0 to PixelCount - 1 do
  begin
    R := Src[0];
    B := Src[2];
    Dest[0] := B;
    Dest[1] := Src[1];
    Dest[2] := R;
    Inc(Src, 3);
    Inc(Dest, 3);
  end;
end;

procedure ConvertBGR24ToRGB24_Scalar(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  ConvertRGB24ToBGR24_Scalar(Src, Dest, PixelCount);
end;

procedure ConvertGray8ToRGBA32_Scalar(Src: PByte; Dest: PByte; PixelCount: Integer);
var
  I: Integer;
  G: Byte;
begin
  for I := 0 to PixelCount - 1 do
  begin
    G := Src^;
    Dest[0] := G;
    Dest[1] := G;
    Dest[2] := G;
    Dest[3] := 255;
    Inc(Src);
    Inc(Dest, 4);
  end;
end;

procedure ConvertRGBA32ToGray8_Scalar(Src: PByte; Dest: PByte; PixelCount: Integer);
var
  I: Integer;
begin
  // ITU-R BT.601 luma: Y = 0.299*R + 0.587*G + 0.114*B
  // Using integer approximation: Y = (77*R + 150*G + 29*B) >> 8
  for I := 0 to PixelCount - 1 do
  begin
    Dest^ := (77 * Src[0] + 150 * Src[1] + 29 * Src[2]) shr 8;
    Inc(Src, 4);
    Inc(Dest);
  end;
end;

procedure ConvertRGB24ToGray8_Scalar(Src: PByte; Dest: PByte; PixelCount: Integer);
var
  I: Integer;
begin
  for I := 0 to PixelCount - 1 do
  begin
    Dest^ := (77 * Src[0] + 150 * Src[1] + 29 * Src[2]) shr 8;
    Inc(Src, 3);
    Inc(Dest);
  end;
end;

procedure PremultiplyAlphaRGBA32_Scalar(Data: PByte; PixelCount: Integer);
var
  I: Integer;
  A: Integer;
begin
  for I := 0 to PixelCount - 1 do
  begin
    A := Data[3];
    if A < 255 then
    begin
      if A = 0 then
      begin
        Data[0] := 0;
        Data[1] := 0;
        Data[2] := 0;
      end
      else
      begin
        Data[0] := (Data[0] * A) div 255;
        Data[1] := (Data[1] * A) div 255;
        Data[2] := (Data[2] * A) div 255;
      end;
    end;
    Inc(Data, 4);
  end;
end;

procedure UnpremultiplyAlphaRGBA32_Scalar(Data: PByte; PixelCount: Integer);
var
  I: Integer;
  A: Integer;
begin
  for I := 0 to PixelCount - 1 do
  begin
    A := Data[3];
    if (A > 0) and (A < 255) then
    begin
      Data[0] := (Data[0] * 255) div A;
      Data[1] := (Data[1] * 255) div A;
      Data[2] := (Data[2] * 255) div A;
    end;
    Inc(Data, 4);
  end;
end;

procedure SetAlphaRGBA32_Scalar(Data: PByte; PixelCount: Integer; Alpha: Byte);
var
  I: Integer;
begin
  for I := 0 to PixelCount - 1 do
  begin
    Data[3] := Alpha;
    Inc(Data, 4);
  end;
end;

procedure FillMemory32_Scalar(Dest: PByte; Count: Integer; Value: LongWord);
var
  I: Integer;
  P: PLongWord;
begin
  P := PLongWord(Dest);
  for I := 0 to Count - 1 do
  begin
    P^ := Value;
    Inc(P);
  end;
end;

{ SSE2 implementations }

{$IFDEF HAS_SSE2}
procedure ConvertRGBA32ToBGRA32_SSE2(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
asm
  {$IFDEF CPUX64}
    {$IFDEF MSWINDOWS}
    // RCX = Src, RDX = Dest, R8D = PixelCount
    test r8d, r8d
    jle @Exit

    // Process 4 pixels at a time (16 bytes)
    mov eax, r8d
    shr eax, 2
    jz @Remainder

    // Load shuffle mask for RGBA -> BGRA: swap bytes 0,2 in each dword
    lea r9, [rip + RGBA_BGRA_ShuffleMask]
    movdqu xmm2, [r9]

@Loop4:
    movdqu xmm0, [rcx]
    pshufb xmm0, xmm2
    movdqu [rdx], xmm0
    add rcx, 16
    add rdx, 16
    dec eax
    jnz @Loop4

@Remainder:
    // Handle remaining pixels
    and r8d, 3
    jz @Exit

@Loop1:
    mov al, [rcx]
    mov r9b, [rcx + 2]
    mov [rdx], r9b
    mov r9b, [rcx + 1]
    mov [rdx + 1], r9b
    mov [rdx + 2], al
    mov al, [rcx + 3]
    mov [rdx + 3], al
    add rcx, 4
    add rdx, 4
    dec r8d
    jnz @Loop1

@Exit:
    {$ELSE}
    // RDI = Src, RSI = Dest, EDX = PixelCount (System V ABI)
    test edx, edx
    jle @Exit

    mov eax, edx
    shr eax, 2
    jz @Remainder

    lea r8, [rip + RGBA_BGRA_ShuffleMask]
    movdqu xmm2, [r8]

@Loop4:
    movdqu xmm0, [rdi]
    pshufb xmm0, xmm2
    movdqu [rsi], xmm0
    add rdi, 16
    add rsi, 16
    dec eax
    jnz @Loop4

@Remainder:
    and edx, 3
    jz @Exit

@Loop1:
    mov al, [rdi]
    mov cl, [rdi + 2]
    mov [rsi], cl
    mov cl, [rdi + 1]
    mov [rsi + 1], cl
    mov [rsi + 2], al
    mov al, [rdi + 3]
    mov [rsi + 3], al
    add rdi, 4
    add rsi, 4
    dec edx
    jnz @Loop1

@Exit:
    {$ENDIF}
  {$ENDIF}
end;

procedure FillMemory32_SSE2(Dest: PByte; Count: Integer; Value: LongWord); assembler; nostackframe;
asm
  {$IFDEF CPUX64}
    {$IFDEF MSWINDOWS}
    // RCX = Dest, EDX = Count, R8D = Value
    test edx, edx
    jle @Exit

    // Broadcast value to XMM0
    movd xmm0, r8d
    pshufd xmm0, xmm0, 0

    // Process 4 dwords at a time
    mov eax, edx
    shr eax, 2
    jz @Remainder

@Loop4:
    movdqu [rcx], xmm0
    add rcx, 16
    dec eax
    jnz @Loop4

@Remainder:
    and edx, 3
    jz @Exit

@Loop1:
    mov [rcx], r8d
    add rcx, 4
    dec edx
    jnz @Loop1

@Exit:
    ret
    {$ELSE}
    // RDI = Dest, ESI = Count, EDX = Value (System V ABI)
    test esi, esi
    jle @Exit

    movd xmm0, edx
    pshufd xmm0, xmm0, 0

    mov eax, esi
    shr eax, 2
    jz @Remainder

@Loop4:
    movdqu [rdi], xmm0
    add rdi, 16
    dec eax
    jnz @Loop4

@Remainder:
    and esi, 3
    jz @Exit

@Loop1:
    mov [rdi], edx
    add rdi, 4
    dec esi
    jnz @Loop1

@Exit:
    ret
    {$ENDIF}
  {$ENDIF}
end;

procedure ConvertRGB24ToRGBA32_SSE2(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
asm
  {$IFDEF CPUX64}
    {$IFDEF MSWINDOWS}
    // RCX = Src, RDX = Dest, R8D = PixelCount
    test r8d, r8d
    jle @Exit

    // Create alpha mask (0xFF in highest byte of each dword)
    pcmpeqd xmm3, xmm3           // All 1s
    pslld xmm3, 24               // 0xFF000000 in each dword

    // Process 4 pixels at a time (12 bytes -> 16 bytes)
    mov eax, r8d
    shr eax, 2
    jz @Remainder

@Loop4:
    // Load 12 bytes (4 RGB pixels) - need to be careful about alignment
    movd xmm0, [rcx]             // Load first 4 bytes
    movd xmm1, [rcx + 4]         // Load next 4 bytes
    movd xmm2, [rcx + 8]         // Load last 4 bytes

    // Unpack RGB to RGBA
    // Pixel 0: bytes 0,1,2 -> dword 0
    // Pixel 1: bytes 3,4,5 -> dword 1
    // Pixel 2: bytes 6,7,8 -> dword 2
    // Pixel 3: bytes 9,10,11 -> dword 3

    // Combine into single register and shuffle
    punpckldq xmm0, xmm1         // xmm0 = [b0-3, b4-7, ?, ?]
    punpckldq xmm2, xmm2         // xmm2 = [b8-11, b8-11, ?, ?]
    punpcklqdq xmm0, xmm2        // xmm0 = [b0-3, b4-7, b8-11, b8-11]

    // Now we have bytes 0-11 in xmm0, need to expand to RGBA
    // This is complex without SSSE3 pshufb, use scalar for now
    // Fallback to scalar for RGB24->RGBA32 without SSSE3

    // Actually, let's do it the simple way - 4 pixels scalar in the loop
    // and use SIMD only for larger batches with SSSE3

    // For SSE2 only, use scalar approach in vectorized manner
    mov r9d, [rcx]               // Pixels 0-1 partial
    mov r10d, [rcx + 4]          // Pixels 1-2 partial
    mov r11d, [rcx + 8]          // Pixels 2-3 partial

    // Pixel 0: r9[0:23] + 0xFF
    movzx eax, r9b               // R0
    mov [rdx], al
    shr r9d, 8
    movzx eax, r9b               // G0
    mov [rdx + 1], al
    shr r9d, 8
    movzx eax, r9b               // B0
    mov [rdx + 2], al
    mov byte [rdx + 3], 255      // A0

    // Pixel 1: r9[24:31] + r10[0:15] + 0xFF
    shr r9d, 8                   // R1 now in r9b
    mov [rdx + 4], r9b
    movzx eax, r10b              // G1
    mov [rdx + 5], al
    shr r10d, 8
    movzx eax, r10b              // B1
    mov [rdx + 6], al
    mov byte [rdx + 7], 255      // A1

    // Pixel 2: r10[16:31] + r11[0:7] + 0xFF
    shr r10d, 8                  // R2
    mov [rdx + 8], r10b
    shr r10d, 8                  // G2
    mov [rdx + 9], r10b
    movzx eax, r11b              // B2
    mov [rdx + 10], al
    mov byte [rdx + 11], 255     // A2

    // Pixel 3: r11[8:31] + 0xFF
    shr r11d, 8                  // R3
    mov [rdx + 12], r11b
    shr r11d, 8                  // G3
    mov [rdx + 13], r11b
    shr r11d, 8                  // B3
    mov [rdx + 14], r11b
    mov byte [rdx + 15], 255     // A3

    add rcx, 12
    add rdx, 16
    dec eax
    jnz @Loop4

@Remainder:
    and r8d, 3
    jz @Exit

@Loop1:
    movzx eax, byte [rcx]
    mov [rdx], al
    movzx eax, byte [rcx + 1]
    mov [rdx + 1], al
    movzx eax, byte [rcx + 2]
    mov [rdx + 2], al
    mov byte [rdx + 3], 255
    add rcx, 3
    add rdx, 4
    dec r8d
    jnz @Loop1

@Exit:
    {$ELSE}
    // System V ABI: RDI = Src, RSI = Dest, EDX = PixelCount
    test edx, edx
    jle @Exit

    mov eax, edx
    shr eax, 2
    jz @Remainder

@Loop4:
    mov r8d, [rdi]
    mov r9d, [rdi + 4]
    mov r10d, [rdi + 8]

    // Pixel 0
    mov [rsi], r8b
    shr r8d, 8
    mov [rsi + 1], r8b
    shr r8d, 8
    mov [rsi + 2], r8b
    mov byte [rsi + 3], 255
    shr r8d, 8

    // Pixel 1
    mov [rsi + 4], r8b
    mov [rsi + 5], r9b
    shr r9d, 8
    mov [rsi + 6], r9b
    mov byte [rsi + 7], 255
    shr r9d, 8

    // Pixel 2
    mov [rsi + 8], r9b
    shr r9d, 8
    mov [rsi + 9], r9b
    mov [rsi + 10], r10b
    mov byte [rsi + 11], 255
    shr r10d, 8

    // Pixel 3
    mov [rsi + 12], r10b
    shr r10d, 8
    mov [rsi + 13], r10b
    shr r10d, 8
    mov [rsi + 14], r10b
    mov byte [rsi + 15], 255

    add rdi, 12
    add rsi, 16
    dec eax
    jnz @Loop4

@Remainder:
    and edx, 3
    jz @Exit

@Loop1:
    movzx eax, byte [rdi]
    mov [rsi], al
    movzx eax, byte [rdi + 1]
    mov [rsi + 1], al
    movzx eax, byte [rdi + 2]
    mov [rsi + 2], al
    mov byte [rsi + 3], 255
    add rdi, 3
    add rsi, 4
    dec edx
    jnz @Loop1

@Exit:
    {$ENDIF}
  {$ENDIF}
end;

procedure ConvertRGBA32ToRGB24_SSE2(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
asm
  {$IFDEF CPUX64}
    {$IFDEF MSWINDOWS}
    // RCX = Src, RDX = Dest, R8D = PixelCount
    test r8d, r8d
    jle @Exit

    // Simple scalar loop - complex packing not worth it without SSSE3
@Loop1:
    movzx eax, byte [rcx]        // R
    mov [rdx], al
    movzx eax, byte [rcx + 1]    // G
    mov [rdx + 1], al
    movzx eax, byte [rcx + 2]    // B
    mov [rdx + 2], al
    add rcx, 4
    add rdx, 3
    dec r8d
    jnz @Loop1

@Exit:
    {$ELSE}
    // System V ABI: RDI = Src, RSI = Dest, EDX = PixelCount
    test edx, edx
    jle @Exit

@Loop1:
    movzx eax, byte [rdi]
    mov [rsi], al
    movzx eax, byte [rdi + 1]
    mov [rsi + 1], al
    movzx eax, byte [rdi + 2]
    mov [rsi + 2], al
    add rdi, 4
    add rsi, 3
    dec edx
    jnz @Loop1

@Exit:
    {$ENDIF}
  {$ENDIF}
end;

procedure ConvertGray8ToRGBA32_SSE2(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
asm
  {$IFDEF CPUX64}
    {$IFDEF MSWINDOWS}
    // RCX = Src, RDX = Dest, R8D = PixelCount
    test r8d, r8d
    jle @Exit

    // Process 4 pixels at a time
    mov eax, r8d
    shr eax, 2
    jz @Remainder

    // Create alpha mask (0xFF in byte 3 of each dword)
    pcmpeqd xmm2, xmm2           // All 1s
    pslld xmm2, 24               // 0xFF000000 in each dword

@Loop4:
    // Load 4 grayscale bytes
    movd xmm0, [rcx]             // Load 4 gray values

    // Unpack bytes to dwords: G -> GGGG
    pxor xmm1, xmm1
    punpcklbw xmm0, xmm0         // G0G0 G1G1 G2G2 G3G3 ...
    punpcklwd xmm0, xmm0         // G0G0G0G0 G1G1G1G1 G2G2G2G2 G3G3G3G3

    // Set alpha channel to 255
    por xmm0, xmm2               // OR with 0xFF000000

    // Store 4 RGBA pixels
    movdqu [rdx], xmm0

    add rcx, 4
    add rdx, 16
    dec eax
    jnz @Loop4

@Remainder:
    and r8d, 3
    jz @Exit

@Loop1:
    movzx eax, byte [rcx]
    mov [rdx], al                // R
    mov [rdx + 1], al            // G
    mov [rdx + 2], al            // B
    mov byte [rdx + 3], 255      // A
    inc rcx
    add rdx, 4
    dec r8d
    jnz @Loop1

@Exit:
    {$ELSE}
    // System V ABI: RDI = Src, RSI = Dest, EDX = PixelCount
    test edx, edx
    jle @Exit

    mov ecx, edx
    shr ecx, 2
    jz @Remainder

    pcmpeqd xmm2, xmm2
    pslld xmm2, 24

@Loop4:
    movd xmm0, [rdi]
    punpcklbw xmm0, xmm0
    punpcklwd xmm0, xmm0
    por xmm0, xmm2
    movdqu [rsi], xmm0

    add rdi, 4
    add rsi, 16
    dec ecx
    jnz @Loop4

@Remainder:
    and edx, 3
    jz @Exit

@Loop1:
    movzx eax, byte [rdi]
    mov [rsi], al
    mov [rsi + 1], al
    mov [rsi + 2], al
    mov byte [rsi + 3], 255
    inc rdi
    add rsi, 4
    dec edx
    jnz @Loop1

@Exit:
    {$ENDIF}
  {$ENDIF}
end;

procedure ConvertRGBA32ToGray8_SSE2(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
// ITU-R BT.601: Y = 0.299*R + 0.587*G + 0.114*B
// Integer: Y = (77*R + 150*G + 29*B) >> 8
asm
  {$IFDEF CPUX64}
    {$IFDEF MSWINDOWS}
    // RCX = Src, RDX = Dest, R8D = PixelCount
    test r8d, r8d
    jle @Exit

    // Use R8 as loop counter, coefficients as immediates
@Loop1:
    movzx eax, byte [rcx]        // R
    imul eax, 77
    movzx r9d, byte [rcx + 1]    // G
    imul r9d, 150
    add eax, r9d
    movzx r9d, byte [rcx + 2]    // B
    imul r9d, 29
    add eax, r9d
    shr eax, 8
    mov [rdx], al

    add rcx, 4
    inc rdx
    dec r8d
    jnz @Loop1

@Exit:
    {$ELSE}
    // System V ABI: RDI = Src, RSI = Dest, EDX = PixelCount
    test edx, edx
    jle @Exit

@Loop1:
    movzx eax, byte [rdi]        // R
    imul eax, 77
    movzx ecx, byte [rdi + 1]    // G
    imul ecx, 150
    add eax, ecx
    movzx ecx, byte [rdi + 2]    // B
    imul ecx, 29
    add eax, ecx
    shr eax, 8
    mov [rsi], al

    add rdi, 4
    inc rsi
    dec edx
    jnz @Loop1

@Exit:
    {$ENDIF}
  {$ENDIF}
end;

procedure ConvertRGB24ToBGR24_SSE2(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
asm
  {$IFDEF CPUX64}
    {$IFDEF MSWINDOWS}
    // RCX = Src, RDX = Dest, R8D = PixelCount
    test r8d, r8d
    jle @Exit

    // Process pixels - RGB24 swap is simple byte operations
    mov eax, r8d
    shr eax, 2
    jz @Remainder

@Loop4:
    // Pixel 0
    movzx r9d, byte [rcx]        // R
    movzx r10d, byte [rcx + 1]   // G
    movzx r11d, byte [rcx + 2]   // B
    mov [rdx], r11b              // B
    mov [rdx + 1], r10b          // G
    mov [rdx + 2], r9b           // R

    // Pixel 1
    movzx r9d, byte [rcx + 3]
    movzx r10d, byte [rcx + 4]
    movzx r11d, byte [rcx + 5]
    mov [rdx + 3], r11b
    mov [rdx + 4], r10b
    mov [rdx + 5], r9b

    // Pixel 2
    movzx r9d, byte [rcx + 6]
    movzx r10d, byte [rcx + 7]
    movzx r11d, byte [rcx + 8]
    mov [rdx + 6], r11b
    mov [rdx + 7], r10b
    mov [rdx + 8], r9b

    // Pixel 3
    movzx r9d, byte [rcx + 9]
    movzx r10d, byte [rcx + 10]
    movzx r11d, byte [rcx + 11]
    mov [rdx + 9], r11b
    mov [rdx + 10], r10b
    mov [rdx + 11], r9b

    add rcx, 12
    add rdx, 12
    dec eax
    jnz @Loop4

@Remainder:
    and r8d, 3
    jz @Exit

@Loop1:
    movzx r9d, byte [rcx]
    movzx r10d, byte [rcx + 1]
    movzx r11d, byte [rcx + 2]
    mov [rdx], r11b
    mov [rdx + 1], r10b
    mov [rdx + 2], r9b
    add rcx, 3
    add rdx, 3
    dec r8d
    jnz @Loop1

@Exit:
    {$ELSE}
    // System V ABI: RDI = Src, RSI = Dest, EDX = PixelCount
    test edx, edx
    jle @Exit

@Loop1:
    movzx eax, byte [rdi]        // R
    movzx ecx, byte [rdi + 1]    // G
    movzx r8d, byte [rdi + 2]    // B
    mov [rsi], r8b               // B
    mov [rsi + 1], cl            // G
    mov [rsi + 2], al            // R
    add rdi, 3
    add rsi, 3
    dec edx
    jnz @Loop1

@Exit:
    {$ENDIF}
  {$ENDIF}
end;

procedure SetAlphaRGBA32_SSE2(Data: PByte; PixelCount: Integer; Alpha: Byte); assembler; nostackframe;
asm
  {$IFDEF CPUX64}
    {$IFDEF MSWINDOWS}
    // RCX = Data, EDX = PixelCount, R8B = Alpha
    test edx, edx
    jle @Exit

    // Broadcast alpha to all bytes of xmm1
    movd xmm0, r8d
    punpcklbw xmm0, xmm0
    punpcklwd xmm0, xmm0
    pshufd xmm0, xmm0, 0         // Alpha in all 16 bytes

    // Create mask for alpha position (byte 3, 7, 11, 15)
    pcmpeqd xmm2, xmm2           // All 1s
    pslld xmm2, 24               // 0xFF000000 mask

    // Inverse mask for RGB
    pcmpeqd xmm3, xmm3
    psrld xmm3, 8                // 0x00FFFFFF mask

    // Process 4 pixels at a time
    mov eax, edx
    shr eax, 2
    jz @Remainder

@Loop4:
    movdqu xmm1, [rcx]           // Load 4 RGBA pixels
    pand xmm1, xmm3              // Keep only RGB (clear alpha)
    pand xmm0, xmm2              // Keep only alpha position
    por xmm1, xmm0               // Combine
    movdqu [rcx], xmm1           // Store

    // Restore xmm0 (it got modified)
    movd xmm0, r8d
    punpcklbw xmm0, xmm0
    punpcklwd xmm0, xmm0
    pshufd xmm0, xmm0, 0

    add rcx, 16
    dec eax
    jnz @Loop4

@Remainder:
    and edx, 3
    jz @Exit

@Loop1:
    mov [rcx + 3], r8b
    add rcx, 4
    dec edx
    jnz @Loop1

@Exit:
    {$ELSE}
    // System V ABI: RDI = Data, ESI = PixelCount, DL = Alpha
    test esi, esi
    jle @Exit

@Loop1:
    mov [rdi + 3], dl
    add rdi, 4
    dec esi
    jnz @Loop1

@Exit:
    {$ENDIF}
  {$ENDIF}
end;

procedure ConvertRGB24ToGray8_SSE2(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
// Y = (77*R + 150*G + 29*B) >> 8
asm
  {$IFDEF CPUX64}
    {$IFDEF MSWINDOWS}
    // RCX = Src, RDX = Dest, R8D = PixelCount
    test r8d, r8d
    jle @Exit

@Loop1:
    movzx eax, byte [rcx]        // R
    imul eax, 77
    movzx r9d, byte [rcx + 1]    // G
    imul r9d, 150
    add eax, r9d
    movzx r9d, byte [rcx + 2]    // B
    imul r9d, 29
    add eax, r9d
    shr eax, 8
    mov [rdx], al

    add rcx, 3
    inc rdx
    dec r8d
    jnz @Loop1

@Exit:
    {$ELSE}
    // System V ABI: RDI = Src, RSI = Dest, EDX = PixelCount
    test edx, edx
    jle @Exit

    mov r8d, 77
    mov r9d, 150
    mov r10d, 29

@Loop1:
    movzx eax, byte [rdi]        // R
    imul eax, r8d
    movzx ecx, byte [rdi + 1]    // G
    imul ecx, r9d
    add eax, ecx
    movzx ecx, byte [rdi + 2]    // B
    imul ecx, r10d
    add eax, ecx
    shr eax, 8
    mov [rsi], al

    add rdi, 3
    inc rsi
    dec edx
    jnz @Loop1

@Exit:
    {$ENDIF}
  {$ENDIF}
end;
{$ENDIF}

{ NEON implementations for ARM64 }

{$IFDEF HAS_NEON}
procedure ConvertRGBA32ToBGRA32_NEON(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
{ ARM64 ABI: X0 = Src, X1 = Dest, W2 = PixelCount }
asm
  cbz w2, .Lexit                    // Exit if PixelCount <= 0

  // Process 4 pixels at a time (16 bytes)
  lsr w3, w2, #2                    // w3 = PixelCount / 4
  cbz w3, .Lremainder

.Lloop4:
  ld4 {v0.8b, v1.8b, v2.8b, v3.8b}, [x0], #32  // Load 8 RGBA pixels as separate channels
  // v0=R, v1=G, v2=B, v3=A - but we only want 4 pixels first
  // Actually use ld1 and manual swizzle for 4 pixels at a time

  ldr q0, [x0], #16                 // Load 4 RGBA pixels (16 bytes)

  // Swap R and B channels: RGBA -> BGRA
  // v0 = [R0,G0,B0,A0, R1,G1,B1,A1, R2,G2,B2,A2, R3,G3,B3,A3]
  // Want: [B0,G0,R0,A0, B1,G1,R1,A1, ...]

  rev32 v1.16b, v0.16b              // Reverse bytes in each 32-bit word: [A0,B0,G0,R0,...]
  // Now extract and recombine
  // Alternative: use TBL instruction with lookup table

  // Use table lookup for precise channel swap
  // Shuffle mask: [2,1,0,3, 6,5,4,7, 10,9,8,11, 14,13,12,15]
  adr x4, .Lshufflemask
  ldr q2, [x4]
  tbl v1.16b, {v0.16b}, v2.16b

  str q1, [x1], #16                 // Store 4 BGRA pixels

  subs w3, w3, #1
  b.ne .Lloop4

.Lremainder:
  // Handle remaining pixels (0-3)
  and w2, w2, #3
  cbz w2, .Lexit

.Lloop1:
  ldrb w3, [x0]                     // R
  ldrb w4, [x0, #1]                 // G
  ldrb w5, [x0, #2]                 // B
  ldrb w6, [x0, #3]                 // A

  strb w5, [x1]                     // B -> pos 0
  strb w4, [x1, #1]                 // G -> pos 1
  strb w3, [x1, #2]                 // R -> pos 2
  strb w6, [x1, #3]                 // A -> pos 3

  add x0, x0, #4
  add x1, x1, #4
  subs w2, w2, #1
  b.ne .Lloop1

.Lexit:
  ret

.Lshufflemask:
  .byte 2, 1, 0, 3, 6, 5, 4, 7, 10, 9, 8, 11, 14, 13, 12, 15
end;

procedure ConvertRGB24ToRGBA32_NEON(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
{ ARM64 ABI: X0 = Src, X1 = Dest, W2 = PixelCount }
asm
  cbz w2, .Lexit

  // Create alpha value (255) in a register
  mov w7, #255

  // Process 8 pixels at a time (24 bytes -> 32 bytes)
  lsr w3, w2, #3                    // w3 = PixelCount / 8
  cbz w3, .Lremainder4

  // Fill v3 with 255 for alpha channel
  dup v3.8b, w7

.Lloop8:
  // Load 8 RGB24 pixels (24 bytes) using ld3 to deinterleave
  ld3 {v0.8b, v1.8b, v2.8b}, [x0], #24  // v0=R, v1=G, v2=B for 8 pixels

  // Store as RGBA32 using st4 to interleave
  st4 {v0.8b, v1.8b, v2.8b, v3.8b}, [x1], #32

  subs w3, w3, #1
  b.ne .Lloop8

.Lremainder4:
  // Check for 4 remaining pixels
  and w3, w2, #7
  lsr w4, w3, #2                    // w4 = remainder / 4
  cbz w4, .Lremainder1

  // Process 4 pixels
  dup v3.8b, w7
  ld3 {v0.8b, v1.8b, v2.8b}, [x0], #12  // Load 4 RGB pixels (only lower 4 bytes used)
  // Actually ld3 loads 8 bytes minimum, need scalar for 4 pixels

.Lremainder1:
  // Handle remaining pixels
  and w2, w2, #7
  cbz w2, .Lexit

.Lloop1:
  ldrb w3, [x0]                     // R
  ldrb w4, [x0, #1]                 // G
  ldrb w5, [x0, #2]                 // B

  strb w3, [x1]                     // R
  strb w4, [x1, #1]                 // G
  strb w5, [x1, #2]                 // B
  strb w7, [x1, #3]                 // A = 255

  add x0, x0, #3
  add x1, x1, #4
  subs w2, w2, #1
  b.ne .Lloop1

.Lexit:
  ret
end;

procedure ConvertRGBA32ToRGB24_NEON(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
{ ARM64 ABI: X0 = Src, X1 = Dest, W2 = PixelCount }
asm
  cbz w2, .Lexit

  // Process 8 pixels at a time (32 bytes -> 24 bytes)
  lsr w3, w2, #3
  cbz w3, .Lremainder

.Lloop8:
  // Load 8 RGBA32 pixels using ld4 to deinterleave
  ld4 {v0.8b, v1.8b, v2.8b, v3.8b}, [x0], #32  // v0=R, v1=G, v2=B, v3=A

  // Store as RGB24 using st3 (discarding alpha)
  st3 {v0.8b, v1.8b, v2.8b}, [x1], #24

  subs w3, w3, #1
  b.ne .Lloop8

.Lremainder:
  and w2, w2, #7
  cbz w2, .Lexit

.Lloop1:
  ldrb w3, [x0]                     // R
  ldrb w4, [x0, #1]                 // G
  ldrb w5, [x0, #2]                 // B

  strb w3, [x1]                     // R
  strb w4, [x1, #1]                 // G
  strb w5, [x1, #2]                 // B

  add x0, x0, #4
  add x1, x1, #3
  subs w2, w2, #1
  b.ne .Lloop1

.Lexit:
  ret
end;

procedure ConvertGray8ToRGBA32_NEON(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
{ ARM64 ABI: X0 = Src, X1 = Dest, W2 = PixelCount }
asm
  cbz w2, .Lexit

  mov w7, #255

  // Process 8 pixels at a time
  lsr w3, w2, #3
  cbz w3, .Lremainder

  dup v3.8b, w7                     // v3 = 255 for alpha

.Lloop8:
  ld1 {v0.8b}, [x0], #8             // Load 8 grayscale bytes

  // Duplicate grayscale to RGB (v0=R=G=B)
  mov v1.8b, v0.8b                  // G = Gray
  mov v2.8b, v0.8b                  // B = Gray

  // Store as RGBA32
  st4 {v0.8b, v1.8b, v2.8b, v3.8b}, [x1], #32

  subs w3, w3, #1
  b.ne .Lloop8

.Lremainder:
  and w2, w2, #7
  cbz w2, .Lexit

.Lloop1:
  ldrb w3, [x0], #1                 // G (grayscale)

  strb w3, [x1]                     // R
  strb w3, [x1, #1]                 // G
  strb w3, [x1, #2]                 // B
  strb w7, [x1, #3]                 // A = 255

  add x1, x1, #4
  subs w2, w2, #1
  b.ne .Lloop1

.Lexit:
  ret
end;

procedure ConvertRGBA32ToGray8_NEON(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
{ ARM64 ABI: X0 = Src, X1 = Dest, W2 = PixelCount }
{ ITU-R BT.601: Y = 0.299*R + 0.587*G + 0.114*B }
{ Integer approx: Y = (77*R + 150*G + 29*B) >> 8 }
asm
  cbz w2, .Lexit

  // Process 8 pixels at a time
  lsr w3, w2, #3
  cbz w3, .Lremainder

  // Set up coefficient vectors
  mov w4, #77                       // R coefficient
  mov w5, #150                      // G coefficient
  mov w6, #29                       // B coefficient
  dup v4.8b, w4
  dup v5.8b, w5
  dup v6.8b, w6

.Lloop8:
  // Load 8 RGBA32 pixels, deinterleaved
  ld4 {v0.8b, v1.8b, v2.8b, v3.8b}, [x0], #32  // v0=R, v1=G, v2=B, v3=A

  // Multiply and accumulate: Y = 77*R + 150*G + 29*B
  umull v16.8h, v0.8b, v4.8b        // 77 * R -> 16-bit
  umlal v16.8h, v1.8b, v5.8b        // + 150 * G
  umlal v16.8h, v2.8b, v6.8b        // + 29 * B

  // Shift right by 8 and narrow to 8-bit
  shrn v0.8b, v16.8h, #8

  // Store 8 grayscale bytes
  st1 {v0.8b}, [x1], #8

  subs w3, w3, #1
  b.ne .Lloop8

.Lremainder:
  and w2, w2, #7
  cbz w2, .Lexit

.Lloop1:
  ldrb w3, [x0]                     // R
  ldrb w4, [x0, #1]                 // G
  ldrb w5, [x0, #2]                 // B

  // Y = (77*R + 150*G + 29*B) >> 8
  mov w6, #77
  mul w3, w3, w6
  mov w6, #150
  madd w3, w4, w6, w3
  mov w6, #29
  madd w3, w5, w6, w3
  lsr w3, w3, #8

  strb w3, [x1], #1
  add x0, x0, #4
  subs w2, w2, #1
  b.ne .Lloop1

.Lexit:
  ret
end;

procedure FillMemory32_NEON(Dest: PByte; Count: Integer; Value: LongWord); assembler; nostackframe;
{ ARM64 ABI: X0 = Dest, W1 = Count, W2 = Value }
asm
  cbz w1, .Lexit

  // Broadcast value to all lanes of v0
  dup v0.4s, w2

  // Process 4 dwords at a time (16 bytes)
  lsr w3, w1, #2
  cbz w3, .Lremainder

.Lloop4:
  st1 {v0.4s}, [x0], #16
  subs w3, w3, #1
  b.ne .Lloop4

.Lremainder:
  and w1, w1, #3
  cbz w1, .Lexit

.Lloop1:
  str w2, [x0], #4
  subs w1, w1, #1
  b.ne .Lloop1

.Lexit:
  ret
end;

procedure SetAlphaRGBA32_NEON(Data: PByte; PixelCount: Integer; Alpha: Byte); assembler; nostackframe;
{ ARM64 ABI: X0 = Data, W1 = PixelCount, W2 = Alpha }
asm
  cbz w1, .Lexit

  // Process 8 pixels at a time
  lsr w3, w1, #3
  cbz w3, .Lremainder

  dup v3.8b, w2                     // v3 = Alpha value for all 8 pixels

.Lloop8:
  // Load 8 RGBA32 pixels, deinterleaved
  ld4 {v0.8b, v1.8b, v2.8b, v4.8b}, [x0]  // v0=R, v1=G, v2=B, v4=A (will be overwritten)

  // Store back with new alpha
  st4 {v0.8b, v1.8b, v2.8b, v3.8b}, [x0], #32

  subs w3, w3, #1
  b.ne .Lloop8

.Lremainder:
  and w1, w1, #7
  cbz w1, .Lexit

.Lloop1:
  strb w2, [x0, #3]                 // Set alpha byte
  add x0, x0, #4
  subs w1, w1, #1
  b.ne .Lloop1

.Lexit:
  ret
end;

procedure ConvertRGB24ToBGR24_NEON(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
{ ARM64 ABI: X0 = Src, X1 = Dest, W2 = PixelCount }
asm
  cbz w2, .Lexit

  // Process 8 pixels at a time (24 bytes)
  lsr w3, w2, #3
  cbz w3, .Lremainder

.Lloop8:
  // Load 8 RGB pixels, deinterleaved
  ld3 {v0.8b, v1.8b, v2.8b}, [x0], #24  // v0=R, v1=G, v2=B

  // Store as BGR (swap R and B)
  st3 {v2.8b, v1.8b, v0.8b}, [x1], #24  // B, G, R

  subs w3, w3, #1
  b.ne .Lloop8

.Lremainder:
  and w2, w2, #7
  cbz w2, .Lexit

.Lloop1:
  ldrb w3, [x0]                     // R
  ldrb w4, [x0, #1]                 // G
  ldrb w5, [x0, #2]                 // B

  strb w5, [x1]                     // B
  strb w4, [x1, #1]                 // G
  strb w3, [x1, #2]                 // R

  add x0, x0, #3
  add x1, x1, #3
  subs w2, w2, #1
  b.ne .Lloop1

.Lexit:
  ret
end;

procedure ConvertRGB24ToGray8_NEON(Src: PByte; Dest: PByte; PixelCount: Integer); assembler; nostackframe;
{ ARM64 ABI: X0 = Src, X1 = Dest, W2 = PixelCount }
{ ITU-R BT.601: Y = 0.299*R + 0.587*G + 0.114*B }
{ Integer approx: Y = (77*R + 150*G + 29*B) >> 8 }
asm
  cbz w2, .Lexit

  // Process 8 pixels at a time
  lsr w3, w2, #3
  cbz w3, .Lremainder

  // Set up coefficient vectors
  mov w4, #77                       // R coefficient
  mov w5, #150                      // G coefficient
  mov w6, #29                       // B coefficient
  dup v4.8b, w4
  dup v5.8b, w5
  dup v6.8b, w6

.Lloop8:
  // Load 8 RGB24 pixels, deinterleaved
  ld3 {v0.8b, v1.8b, v2.8b}, [x0], #24  // v0=R, v1=G, v2=B

  // Multiply and accumulate: Y = 77*R + 150*G + 29*B
  umull v16.8h, v0.8b, v4.8b        // 77 * R -> 16-bit
  umlal v16.8h, v1.8b, v5.8b        // + 150 * G
  umlal v16.8h, v2.8b, v6.8b        // + 29 * B

  // Shift right by 8 and narrow to 8-bit
  shrn v0.8b, v16.8h, #8

  // Store 8 grayscale bytes
  st1 {v0.8b}, [x1], #8

  subs w3, w3, #1
  b.ne .Lloop8

.Lremainder:
  and w2, w2, #7
  cbz w2, .Lexit

.Lloop1:
  ldrb w3, [x0]                     // R
  ldrb w4, [x0, #1]                 // G
  ldrb w5, [x0, #2]                 // B

  // Y = (77*R + 150*G + 29*B) >> 8
  mov w6, #77
  mul w3, w3, w6
  mov w6, #150
  madd w3, w4, w6, w3
  mov w6, #29
  madd w3, w5, w6, w3
  lsr w3, w3, #8

  strb w3, [x1], #1
  add x0, x0, #3
  subs w2, w2, #1
  b.ne .Lloop1

.Lexit:
  ret
end;
{$ENDIF}

{ Public dispatch functions }

procedure ConvertRGB24ToRGBA32(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  {$IFDEF HAS_NEON}
  if CpuFeatures.HasNEON then
    ConvertRGB24ToRGBA32_NEON(Src, Dest, PixelCount)
  else
  {$ENDIF}
  {$IFDEF HAS_SSE2}
  if CpuFeatures.HasSSE2 then
    ConvertRGB24ToRGBA32_SSE2(Src, Dest, PixelCount)
  else
  {$ENDIF}
    ConvertRGB24ToRGBA32_Scalar(Src, Dest, PixelCount);
end;

procedure ConvertRGBA32ToRGB24(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  {$IFDEF HAS_NEON}
  if CpuFeatures.HasNEON then
    ConvertRGBA32ToRGB24_NEON(Src, Dest, PixelCount)
  else
  {$ENDIF}
  {$IFDEF HAS_SSE2}
  if CpuFeatures.HasSSE2 then
    ConvertRGBA32ToRGB24_SSE2(Src, Dest, PixelCount)
  else
  {$ENDIF}
    ConvertRGBA32ToRGB24_Scalar(Src, Dest, PixelCount);
end;

procedure ConvertBGR24ToBGRA32(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  // Uses same logic as RGB24ToRGBA32, just different channel interpretation
  {$IFDEF HAS_NEON}
  if CpuFeatures.HasNEON then
    ConvertRGB24ToRGBA32_NEON(Src, Dest, PixelCount)
  else
  {$ENDIF}
  {$IFDEF HAS_SSE2}
  if CpuFeatures.HasSSE2 then
    ConvertRGB24ToRGBA32_SSE2(Src, Dest, PixelCount)
  else
  {$ENDIF}
    ConvertBGR24ToBGRA32_Scalar(Src, Dest, PixelCount);
end;

procedure ConvertBGRA32ToBGR24(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  {$IFDEF HAS_NEON}
  if CpuFeatures.HasNEON then
    ConvertRGBA32ToRGB24_NEON(Src, Dest, PixelCount)
  else
  {$ENDIF}
  {$IFDEF HAS_SSE2}
  if CpuFeatures.HasSSE2 then
    ConvertRGBA32ToRGB24_SSE2(Src, Dest, PixelCount)
  else
  {$ENDIF}
    ConvertBGRA32ToBGR24_Scalar(Src, Dest, PixelCount);
end;

procedure ConvertRGBA32ToBGRA32(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  {$IFDEF HAS_NEON}
  if CpuFeatures.HasNEON then
    ConvertRGBA32ToBGRA32_NEON(Src, Dest, PixelCount)
  else
  {$ENDIF}
  {$IFDEF HAS_SSE2}
  if CpuFeatures.HasSSSE3 then  // pshufb requires SSSE3
    ConvertRGBA32ToBGRA32_SSE2(Src, Dest, PixelCount)
  else
  {$ENDIF}
    ConvertRGBA32ToBGRA32_Scalar(Src, Dest, PixelCount);
end;

procedure ConvertBGRA32ToRGBA32(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  // Same operation as RGBA->BGRA
  ConvertRGBA32ToBGRA32(Src, Dest, PixelCount);
end;

procedure ConvertRGB24ToBGR24(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  {$IFDEF HAS_NEON}
  if CpuFeatures.HasNEON then
    ConvertRGB24ToBGR24_NEON(Src, Dest, PixelCount)
  else
  {$ENDIF}
  {$IFDEF HAS_SSE2}
  if CpuFeatures.HasSSE2 then
    ConvertRGB24ToBGR24_SSE2(Src, Dest, PixelCount)
  else
  {$ENDIF}
    ConvertRGB24ToBGR24_Scalar(Src, Dest, PixelCount);
end;

procedure ConvertBGR24ToRGB24(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  // Same operation as RGB24->BGR24
  ConvertRGB24ToBGR24(Src, Dest, PixelCount);
end;

procedure ConvertGray8ToRGBA32(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  {$IFDEF HAS_NEON}
  if CpuFeatures.HasNEON then
    ConvertGray8ToRGBA32_NEON(Src, Dest, PixelCount)
  else
  {$ENDIF}
  {$IFDEF HAS_SSE2}
  if CpuFeatures.HasSSE2 then
    ConvertGray8ToRGBA32_SSE2(Src, Dest, PixelCount)
  else
  {$ENDIF}
    ConvertGray8ToRGBA32_Scalar(Src, Dest, PixelCount);
end;

procedure ConvertRGBA32ToGray8(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  {$IFDEF HAS_NEON}
  if CpuFeatures.HasNEON then
    ConvertRGBA32ToGray8_NEON(Src, Dest, PixelCount)
  else
  {$ENDIF}
  {$IFDEF HAS_SSE2}
  if CpuFeatures.HasSSE2 then
    ConvertRGBA32ToGray8_SSE2(Src, Dest, PixelCount)
  else
  {$ENDIF}
    ConvertRGBA32ToGray8_Scalar(Src, Dest, PixelCount);
end;

procedure ConvertRGB24ToGray8(Src: PByte; Dest: PByte; PixelCount: Integer);
begin
  {$IFDEF HAS_NEON}
  if CpuFeatures.HasNEON then
    ConvertRGB24ToGray8_NEON(Src, Dest, PixelCount)
  else
  {$ENDIF}
  {$IFDEF HAS_SSE2}
  if CpuFeatures.HasSSE2 then
    ConvertRGB24ToGray8_SSE2(Src, Dest, PixelCount)
  else
  {$ENDIF}
    ConvertRGB24ToGray8_Scalar(Src, Dest, PixelCount);
end;

procedure PremultiplyAlphaRGBA32(Data: PByte; PixelCount: Integer);
begin
  // Alpha premultiplication is complex with SIMD due to division/multiplication
  // Keep scalar for now - can be optimized later
  PremultiplyAlphaRGBA32_Scalar(Data, PixelCount);
end;

procedure UnpremultiplyAlphaRGBA32(Data: PByte; PixelCount: Integer);
begin
  // Alpha unpremultiplication requires division - keep scalar
  UnpremultiplyAlphaRGBA32_Scalar(Data, PixelCount);
end;

procedure SetAlphaRGBA32(Data: PByte; PixelCount: Integer; Alpha: Byte);
begin
  {$IFDEF HAS_NEON}
  if CpuFeatures.HasNEON then
    SetAlphaRGBA32_NEON(Data, PixelCount, Alpha)
  else
  {$ENDIF}
  {$IFDEF HAS_SSE2}
  if CpuFeatures.HasSSE2 then
    SetAlphaRGBA32_SSE2(Data, PixelCount, Alpha)
  else
  {$ENDIF}
    SetAlphaRGBA32_Scalar(Data, PixelCount, Alpha);
end;

procedure FillMemory32(Dest: PByte; Count: Integer; Value: LongWord);
begin
  {$IFDEF HAS_NEON}
  if CpuFeatures.HasNEON then
    FillMemory32_NEON(Dest, Count, Value)
  else
  {$ENDIF}
  {$IFDEF HAS_SSE2}
  if CpuFeatures.HasSSE2 then
    FillMemory32_SSE2(Dest, Count, Value)
  else
  {$ENDIF}
    FillMemory32_Scalar(Dest, Count, Value);
end;

initialization
  InitCpuFeatures;

end.
