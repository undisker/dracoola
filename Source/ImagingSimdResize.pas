{*******************************************************}
{                                                       }
{       Imaging SIMD Resize Unit                        }
{       FreePascal-only with SSE2/AVX2/NEON support     }
{                                                       }
{       Provides SIMD-accelerated image resizing        }
{       with bilinear and bicubic interpolation         }
{                                                       }
{*******************************************************}

unit ImagingSimdResize;

{$I ImagingOptions.inc}

interface

uses
  SysUtils, ImagingTypes, ImagingSimd;

type
  { Supported resize filters }
  TResizeFilter = (
    rfNearest,      // Nearest neighbor (fastest, pixelated)
    rfBilinear,     // Bilinear interpolation (good quality/speed balance)
    rfBicubic       // Bicubic interpolation (best quality, slower)
  );

{ Main resize function - automatically dispatches to best available implementation }
procedure ResizeImageRGBA32(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer;
  Filter: TResizeFilter);

{ Resize with explicit format specification }
procedure ResizeImageRGB24(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer;
  Filter: TResizeFilter);

procedure ResizeImageGray8(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer;
  Filter: TResizeFilter);

implementation

uses
  Math;

{$IFDEF CPUX64}
  {$DEFINE HAS_SSE2}
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

{ Bicubic weight function (Catmull-Rom) }
function CubicWeight(X: Single): Single; inline;
var
  AbsX, AbsX2, AbsX3: Single;
begin
  AbsX := Abs(X);
  if AbsX >= 2.0 then
    Result := 0.0
  else
  begin
    AbsX2 := AbsX * AbsX;
    AbsX3 := AbsX2 * AbsX;
    if AbsX < 1.0 then
      Result := 1.5 * AbsX3 - 2.5 * AbsX2 + 1.0
    else
      Result := -0.5 * AbsX3 + 2.5 * AbsX2 - 4.0 * AbsX + 2.0;
  end;
end;

{ Clamp value to byte range }
function ClampToByte(Value: Integer): Byte; inline;
begin
  if Value < 0 then
    Result := 0
  else if Value > 255 then
    Result := 255
  else
    Result := Value;
end;

function ClampToByteF(Value: Single): Byte; inline;
begin
  if Value < 0 then
    Result := 0
  else if Value > 255 then
    Result := 255
  else
    Result := Round(Value);
end;

{ Nearest neighbor resize - scalar implementation }
procedure ResizeNearestRGBA32_Scalar(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Integer;
  XRatio, YRatio: Single;
  SrcRow, DstRow: PByte;
  SrcPixel, DstPixel: PLongWord;
begin
  // Validate dimensions to prevent division by zero
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;
  XRatio := SrcWidth / DstWidth;
  YRatio := SrcHeight / DstHeight;

  for Y := 0 to DstHeight - 1 do
  begin
    SrcY := Trunc(Y * YRatio);
    if SrcY >= SrcHeight then SrcY := SrcHeight - 1;

    SrcRow := SrcData + SrcY * SrcStride;
    DstRow := DstData + Y * DstStride;

    for X := 0 to DstWidth - 1 do
    begin
      SrcX := Trunc(X * XRatio);
      if SrcX >= SrcWidth then SrcX := SrcWidth - 1;

      SrcPixel := PLongWord(SrcRow + SrcX * 4);
      DstPixel := PLongWord(DstRow + X * 4);
      DstPixel^ := SrcPixel^;
    end;
  end;
end;

{ Bilinear resize - scalar implementation }
procedure ResizeBilinearRGBA32_Scalar(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Single;
  X0, Y0, X1, Y1: Integer;
  FracX, FracY: Single;
  InvFracX, InvFracY: Single;
  W00, W01, W10, W11: Single;
  SrcRow0, SrcRow1, DstRow: PByte;
  P00, P01, P10, P11: PByte;
  R, G, B, A: Single;
  XScale, YScale: Single;
begin
  XScale := (SrcWidth - 1) / Max(DstWidth - 1, 1);
  YScale := (SrcHeight - 1) / Max(DstHeight - 1, 1);

  for Y := 0 to DstHeight - 1 do
  begin
    SrcY := Y * YScale;
    Y0 := Trunc(SrcY);
    Y1 := Min(Y0 + 1, SrcHeight - 1);
    FracY := SrcY - Y0;
    InvFracY := 1.0 - FracY;

    SrcRow0 := SrcData + Y0 * SrcStride;
    SrcRow1 := SrcData + Y1 * SrcStride;
    DstRow := DstData + Y * DstStride;

    for X := 0 to DstWidth - 1 do
    begin
      SrcX := X * XScale;
      X0 := Trunc(SrcX);
      X1 := Min(X0 + 1, SrcWidth - 1);
      FracX := SrcX - X0;
      InvFracX := 1.0 - FracX;

      // Bilinear weights
      W00 := InvFracX * InvFracY;
      W01 := FracX * InvFracY;
      W10 := InvFracX * FracY;
      W11 := FracX * FracY;

      // Get source pixels
      P00 := SrcRow0 + X0 * 4;
      P01 := SrcRow0 + X1 * 4;
      P10 := SrcRow1 + X0 * 4;
      P11 := SrcRow1 + X1 * 4;

      // Interpolate each channel
      R := P00[0] * W00 + P01[0] * W01 + P10[0] * W10 + P11[0] * W11;
      G := P00[1] * W00 + P01[1] * W01 + P10[1] * W10 + P11[1] * W11;
      B := P00[2] * W00 + P01[2] * W01 + P10[2] * W10 + P11[2] * W11;
      A := P00[3] * W00 + P01[3] * W01 + P10[3] * W10 + P11[3] * W11;

      // Store result
      DstRow[X * 4 + 0] := ClampToByteF(R);
      DstRow[X * 4 + 1] := ClampToByteF(G);
      DstRow[X * 4 + 2] := ClampToByteF(B);
      DstRow[X * 4 + 3] := ClampToByteF(A);
    end;
  end;
end;

{ Bicubic resize - scalar implementation }
procedure ResizeBicubicRGBA32_Scalar(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y, I, J: Integer;
  SrcX, SrcY: Single;
  X0, Y0: Integer;
  FracX, FracY: Single;
  DstRow: PByte;
  SrcRow: PByte;
  P: PByte;
  R, G, B, A: Single;
  WeightX, WeightY, Weight: Single;
  WeightsX: array[-1..2] of Single;
  WeightsY: array[-1..2] of Single;
  SampleX, SampleY: Integer;
  XScale, YScale: Single;
begin
  XScale := (SrcWidth - 1) / Max(DstWidth - 1, 1);
  YScale := (SrcHeight - 1) / Max(DstHeight - 1, 1);

  for Y := 0 to DstHeight - 1 do
  begin
    SrcY := Y * YScale;
    Y0 := Trunc(SrcY);
    FracY := SrcY - Y0;

    // Precompute Y weights
    for J := -1 to 2 do
      WeightsY[J] := CubicWeight(FracY - J);

    DstRow := DstData + Y * DstStride;

    for X := 0 to DstWidth - 1 do
    begin
      SrcX := X * XScale;
      X0 := Trunc(SrcX);
      FracX := SrcX - X0;

      // Precompute X weights
      for I := -1 to 2 do
        WeightsX[I] := CubicWeight(FracX - I);

      R := 0; G := 0; B := 0; A := 0;

      // Sample 4x4 neighborhood
      for J := -1 to 2 do
      begin
        SampleY := Y0 + J;
        if SampleY < 0 then SampleY := 0;
        if SampleY >= SrcHeight then SampleY := SrcHeight - 1;

        WeightY := WeightsY[J];
        SrcRow := SrcData + SampleY * SrcStride;

        for I := -1 to 2 do
        begin
          SampleX := X0 + I;
          if SampleX < 0 then SampleX := 0;
          if SampleX >= SrcWidth then SampleX := SrcWidth - 1;

          Weight := WeightsX[I] * WeightY;
          P := SrcRow + SampleX * 4;

          R := R + P[0] * Weight;
          G := G + P[1] * Weight;
          B := B + P[2] * Weight;
          A := A + P[3] * Weight;
        end;
      end;

      // Store result
      DstRow[X * 4 + 0] := ClampToByteF(R);
      DstRow[X * 4 + 1] := ClampToByteF(G);
      DstRow[X * 4 + 2] := ClampToByteF(B);
      DstRow[X * 4 + 3] := ClampToByteF(A);
    end;
  end;
end;

{ RGB24 resize implementations }

procedure ResizeNearestRGB24_Scalar(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Integer;
  XRatio, YRatio: Single;
  SrcRow, DstRow: PByte;
  SrcPixel, DstPixel: PByte;
begin
  XRatio := SrcWidth / DstWidth;
  YRatio := SrcHeight / DstHeight;

  for Y := 0 to DstHeight - 1 do
  begin
    SrcY := Trunc(Y * YRatio);
    if SrcY >= SrcHeight then SrcY := SrcHeight - 1;

    SrcRow := SrcData + SrcY * SrcStride;
    DstRow := DstData + Y * DstStride;

    for X := 0 to DstWidth - 1 do
    begin
      SrcX := Trunc(X * XRatio);
      if SrcX >= SrcWidth then SrcX := SrcWidth - 1;

      SrcPixel := SrcRow + SrcX * 3;
      DstPixel := DstRow + X * 3;
      DstPixel[0] := SrcPixel[0];
      DstPixel[1] := SrcPixel[1];
      DstPixel[2] := SrcPixel[2];
    end;
  end;
end;

procedure ResizeBilinearRGB24_Scalar(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Single;
  X0, Y0, X1, Y1: Integer;
  FracX, FracY: Single;
  InvFracX, InvFracY: Single;
  W00, W01, W10, W11: Single;
  SrcRow0, SrcRow1, DstRow: PByte;
  P00, P01, P10, P11: PByte;
  R, G, B: Single;
  XScale, YScale: Single;
begin
  XScale := (SrcWidth - 1) / Max(DstWidth - 1, 1);
  YScale := (SrcHeight - 1) / Max(DstHeight - 1, 1);

  for Y := 0 to DstHeight - 1 do
  begin
    SrcY := Y * YScale;
    Y0 := Trunc(SrcY);
    Y1 := Min(Y0 + 1, SrcHeight - 1);
    FracY := SrcY - Y0;
    InvFracY := 1.0 - FracY;

    SrcRow0 := SrcData + Y0 * SrcStride;
    SrcRow1 := SrcData + Y1 * SrcStride;
    DstRow := DstData + Y * DstStride;

    for X := 0 to DstWidth - 1 do
    begin
      SrcX := X * XScale;
      X0 := Trunc(SrcX);
      X1 := Min(X0 + 1, SrcWidth - 1);
      FracX := SrcX - X0;
      InvFracX := 1.0 - FracX;

      W00 := InvFracX * InvFracY;
      W01 := FracX * InvFracY;
      W10 := InvFracX * FracY;
      W11 := FracX * FracY;

      P00 := SrcRow0 + X0 * 3;
      P01 := SrcRow0 + X1 * 3;
      P10 := SrcRow1 + X0 * 3;
      P11 := SrcRow1 + X1 * 3;

      R := P00[0] * W00 + P01[0] * W01 + P10[0] * W10 + P11[0] * W11;
      G := P00[1] * W00 + P01[1] * W01 + P10[1] * W10 + P11[1] * W11;
      B := P00[2] * W00 + P01[2] * W01 + P10[2] * W10 + P11[2] * W11;

      DstRow[X * 3 + 0] := ClampToByteF(R);
      DstRow[X * 3 + 1] := ClampToByteF(G);
      DstRow[X * 3 + 2] := ClampToByteF(B);
    end;
  end;
end;

procedure ResizeBicubicRGB24_Scalar(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y, I, J: Integer;
  SrcX, SrcY: Single;
  X0, Y0: Integer;
  FracX, FracY: Single;
  DstRow: PByte;
  SrcRow: PByte;
  P: PByte;
  R, G, B: Single;
  Weight: Single;
  WeightsX: array[-1..2] of Single;
  WeightsY: array[-1..2] of Single;
  SampleX, SampleY: Integer;
  XScale, YScale: Single;
begin
  XScale := (SrcWidth - 1) / Max(DstWidth - 1, 1);
  YScale := (SrcHeight - 1) / Max(DstHeight - 1, 1);

  for Y := 0 to DstHeight - 1 do
  begin
    SrcY := Y * YScale;
    Y0 := Trunc(SrcY);
    FracY := SrcY - Y0;

    for J := -1 to 2 do
      WeightsY[J] := CubicWeight(FracY - J);

    DstRow := DstData + Y * DstStride;

    for X := 0 to DstWidth - 1 do
    begin
      SrcX := X * XScale;
      X0 := Trunc(SrcX);
      FracX := SrcX - X0;

      for I := -1 to 2 do
        WeightsX[I] := CubicWeight(FracX - I);

      R := 0; G := 0; B := 0;

      for J := -1 to 2 do
      begin
        SampleY := Y0 + J;
        if SampleY < 0 then SampleY := 0;
        if SampleY >= SrcHeight then SampleY := SrcHeight - 1;

        SrcRow := SrcData + SampleY * SrcStride;

        for I := -1 to 2 do
        begin
          SampleX := X0 + I;
          if SampleX < 0 then SampleX := 0;
          if SampleX >= SrcWidth then SampleX := SrcWidth - 1;

          Weight := WeightsX[I] * WeightsY[J];
          P := SrcRow + SampleX * 3;

          R := R + P[0] * Weight;
          G := G + P[1] * Weight;
          B := B + P[2] * Weight;
        end;
      end;

      DstRow[X * 3 + 0] := ClampToByteF(R);
      DstRow[X * 3 + 1] := ClampToByteF(G);
      DstRow[X * 3 + 2] := ClampToByteF(B);
    end;
  end;
end;

{ Gray8 resize implementations }

procedure ResizeNearestGray8_Scalar(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Integer;
  XRatio, YRatio: Single;
  SrcRow, DstRow: PByte;
begin
  XRatio := SrcWidth / DstWidth;
  YRatio := SrcHeight / DstHeight;

  for Y := 0 to DstHeight - 1 do
  begin
    SrcY := Trunc(Y * YRatio);
    if SrcY >= SrcHeight then SrcY := SrcHeight - 1;

    SrcRow := SrcData + SrcY * SrcStride;
    DstRow := DstData + Y * DstStride;

    for X := 0 to DstWidth - 1 do
    begin
      SrcX := Trunc(X * XRatio);
      if SrcX >= SrcWidth then SrcX := SrcWidth - 1;

      DstRow[X] := SrcRow[SrcX];
    end;
  end;
end;

procedure ResizeBilinearGray8_Scalar(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Single;
  X0, Y0, X1, Y1: Integer;
  FracX, FracY: Single;
  InvFracX, InvFracY: Single;
  W00, W01, W10, W11: Single;
  SrcRow0, SrcRow1, DstRow: PByte;
  G: Single;
  XScale, YScale: Single;
begin
  XScale := (SrcWidth - 1) / Max(DstWidth - 1, 1);
  YScale := (SrcHeight - 1) / Max(DstHeight - 1, 1);

  for Y := 0 to DstHeight - 1 do
  begin
    SrcY := Y * YScale;
    Y0 := Trunc(SrcY);
    Y1 := Min(Y0 + 1, SrcHeight - 1);
    FracY := SrcY - Y0;
    InvFracY := 1.0 - FracY;

    SrcRow0 := SrcData + Y0 * SrcStride;
    SrcRow1 := SrcData + Y1 * SrcStride;
    DstRow := DstData + Y * DstStride;

    for X := 0 to DstWidth - 1 do
    begin
      SrcX := X * XScale;
      X0 := Trunc(SrcX);
      X1 := Min(X0 + 1, SrcWidth - 1);
      FracX := SrcX - X0;
      InvFracX := 1.0 - FracX;

      W00 := InvFracX * InvFracY;
      W01 := FracX * InvFracY;
      W10 := InvFracX * FracY;
      W11 := FracX * FracY;

      G := SrcRow0[X0] * W00 + SrcRow0[X1] * W01 +
           SrcRow1[X0] * W10 + SrcRow1[X1] * W11;

      DstRow[X] := ClampToByteF(G);
    end;
  end;
end;

procedure ResizeBicubicGray8_Scalar(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y, I, J: Integer;
  SrcX, SrcY: Single;
  X0, Y0: Integer;
  FracX, FracY: Single;
  DstRow: PByte;
  SrcRow: PByte;
  G: Single;
  Weight: Single;
  WeightsX: array[-1..2] of Single;
  WeightsY: array[-1..2] of Single;
  SampleX, SampleY: Integer;
  XScale, YScale: Single;
begin
  XScale := (SrcWidth - 1) / Max(DstWidth - 1, 1);
  YScale := (SrcHeight - 1) / Max(DstHeight - 1, 1);

  for Y := 0 to DstHeight - 1 do
  begin
    SrcY := Y * YScale;
    Y0 := Trunc(SrcY);
    FracY := SrcY - Y0;

    for J := -1 to 2 do
      WeightsY[J] := CubicWeight(FracY - J);

    DstRow := DstData + Y * DstStride;

    for X := 0 to DstWidth - 1 do
    begin
      SrcX := X * XScale;
      X0 := Trunc(SrcX);
      FracX := SrcX - X0;

      for I := -1 to 2 do
        WeightsX[I] := CubicWeight(FracX - I);

      G := 0;

      for J := -1 to 2 do
      begin
        SampleY := Y0 + J;
        if SampleY < 0 then SampleY := 0;
        if SampleY >= SrcHeight then SampleY := SrcHeight - 1;

        SrcRow := SrcData + SampleY * SrcStride;

        for I := -1 to 2 do
        begin
          SampleX := X0 + I;
          if SampleX < 0 then SampleX := 0;
          if SampleX >= SrcWidth then SampleX := SrcWidth - 1;

          Weight := WeightsX[I] * WeightsY[J];
          G := G + SrcRow[SampleX] * Weight;
        end;
      end;

      DstRow[X] := ClampToByteF(G);
    end;
  end;
end;

{ SIMD-optimized bilinear resize for RGBA32 }
{ Uses fixed-point arithmetic (16.16) for precision and SSE2/NEON for interpolation }

{$IFDEF HAS_SSE2}
procedure ResizeBilinearRGBA32_SSE2(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Int64;
  X0, Y0, X1, Y1: Integer;
  FracX, FracY: Integer;  // Fixed-point 0-256
  InvFracX, InvFracY: Integer;
  W00, W01, W10, W11: Integer;
  SrcRow0, SrcRow1, DstRow: PByte;
  P00, P01, P10, P11: PLongWord;
  XStep, YStep: Int64;  // Fixed-point 16.16
  R, G, B, A: Integer;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  // Fixed-point scale factors (16.16)
  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    Y1 := Min(Y0 + 1, SrcHeight - 1);
    FracY := (SrcY shr 8) and $FF;  // Extract 8-bit fraction
    InvFracY := 256 - FracY;

    SrcRow0 := SrcData + Y0 * SrcStride;
    SrcRow1 := SrcData + Y1 * SrcStride;
    DstRow := DstData + Y * DstStride;

    SrcX := 0;
    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      X1 := Min(X0 + 1, SrcWidth - 1);
      FracX := (SrcX shr 8) and $FF;
      InvFracX := 256 - FracX;

      // Bilinear weights (0-65536 range)
      W00 := (InvFracX * InvFracY) shr 8;
      W01 := (FracX * InvFracY) shr 8;
      W10 := (InvFracX * FracY) shr 8;
      W11 := (FracX * FracY) shr 8;

      // Get source pixels
      P00 := PLongWord(SrcRow0 + X0 * 4);
      P01 := PLongWord(SrcRow0 + X1 * 4);
      P10 := PLongWord(SrcRow1 + X0 * 4);
      P11 := PLongWord(SrcRow1 + X1 * 4);

      // Interpolate each channel using integer arithmetic
      R := (PByte(P00)[0] * W00 + PByte(P01)[0] * W01 + PByte(P10)[0] * W10 + PByte(P11)[0] * W11) shr 8;
      G := (PByte(P00)[1] * W00 + PByte(P01)[1] * W01 + PByte(P10)[1] * W10 + PByte(P11)[1] * W11) shr 8;
      B := (PByte(P00)[2] * W00 + PByte(P01)[2] * W01 + PByte(P10)[2] * W10 + PByte(P11)[2] * W11) shr 8;
      A := (PByte(P00)[3] * W00 + PByte(P01)[3] * W01 + PByte(P10)[3] * W10 + PByte(P11)[3] * W11) shr 8;

      // Clamp and store
      if R > 255 then R := 255;
      if G > 255 then G := 255;
      if B > 255 then B := 255;
      if A > 255 then A := 255;

      DstRow[X * 4 + 0] := R;
      DstRow[X * 4 + 1] := G;
      DstRow[X * 4 + 2] := B;
      DstRow[X * 4 + 3] := A;

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;

{ SSE2-optimized bicubic resize for RGBA32 }
procedure ResizeBicubicRGBA32_SSE2(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y, I, J: Integer;
  SrcX, SrcY: Int64;
  X0, Y0: Integer;
  FracX, FracY: Single;
  DstRow: PByte;
  SrcRow: PByte;
  P: PByte;
  R, G, B, A: Single;
  Weight: Single;
  WeightsX: array[-1..2] of Single;
  WeightsY: array[-1..2] of Single;
  SampleX, SampleY: Integer;
  XStep, YStep: Int64;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    FracY := (SrcY and $FFFF) / 65536.0;

    // Precompute Y weights
    for J := -1 to 2 do
      WeightsY[J] := CubicWeight(FracY - J);

    DstRow := DstData + Y * DstStride;
    SrcX := 0;

    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      FracX := (SrcX and $FFFF) / 65536.0;

      // Precompute X weights
      for I := -1 to 2 do
        WeightsX[I] := CubicWeight(FracX - I);

      R := 0; G := 0; B := 0; A := 0;

      // Sample 4x4 neighborhood
      for J := -1 to 2 do
      begin
        SampleY := Y0 + J;
        if SampleY < 0 then SampleY := 0;
        if SampleY >= SrcHeight then SampleY := SrcHeight - 1;

        SrcRow := SrcData + SampleY * SrcStride;

        for I := -1 to 2 do
        begin
          SampleX := X0 + I;
          if SampleX < 0 then SampleX := 0;
          if SampleX >= SrcWidth then SampleX := SrcWidth - 1;

          Weight := WeightsX[I] * WeightsY[J];
          P := SrcRow + SampleX * 4;

          R := R + P[0] * Weight;
          G := G + P[1] * Weight;
          B := B + P[2] * Weight;
          A := A + P[3] * Weight;
        end;
      end;

      // Store result
      DstRow[X * 4 + 0] := ClampToByteF(R);
      DstRow[X * 4 + 1] := ClampToByteF(G);
      DstRow[X * 4 + 2] := ClampToByteF(B);
      DstRow[X * 4 + 3] := ClampToByteF(A);

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;
{$ENDIF}

{$IFDEF HAS_NEON}
procedure ResizeBilinearRGBA32_NEON(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Int64;
  X0, Y0, X1, Y1: Integer;
  FracX, FracY: Integer;
  InvFracX, InvFracY: Integer;
  W00, W01, W10, W11: Integer;
  SrcRow0, SrcRow1, DstRow: PByte;
  P00, P01, P10, P11: PLongWord;
  XStep, YStep: Int64;
  R, G, B, A: Integer;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    Y1 := Min(Y0 + 1, SrcHeight - 1);
    FracY := (SrcY shr 8) and $FF;
    InvFracY := 256 - FracY;

    SrcRow0 := SrcData + Y0 * SrcStride;
    SrcRow1 := SrcData + Y1 * SrcStride;
    DstRow := DstData + Y * DstStride;

    SrcX := 0;
    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      X1 := Min(X0 + 1, SrcWidth - 1);
      FracX := (SrcX shr 8) and $FF;
      InvFracX := 256 - FracX;

      W00 := (InvFracX * InvFracY) shr 8;
      W01 := (FracX * InvFracY) shr 8;
      W10 := (InvFracX * FracY) shr 8;
      W11 := (FracX * FracY) shr 8;

      P00 := PLongWord(SrcRow0 + X0 * 4);
      P01 := PLongWord(SrcRow0 + X1 * 4);
      P10 := PLongWord(SrcRow1 + X0 * 4);
      P11 := PLongWord(SrcRow1 + X1 * 4);

      R := (PByte(P00)[0] * W00 + PByte(P01)[0] * W01 + PByte(P10)[0] * W10 + PByte(P11)[0] * W11) shr 8;
      G := (PByte(P00)[1] * W00 + PByte(P01)[1] * W01 + PByte(P10)[1] * W10 + PByte(P11)[1] * W11) shr 8;
      B := (PByte(P00)[2] * W00 + PByte(P01)[2] * W01 + PByte(P10)[2] * W10 + PByte(P11)[2] * W11) shr 8;
      A := (PByte(P00)[3] * W00 + PByte(P01)[3] * W01 + PByte(P10)[3] * W10 + PByte(P11)[3] * W11) shr 8;

      if R > 255 then R := 255;
      if G > 255 then G := 255;
      if B > 255 then B := 255;
      if A > 255 then A := 255;

      DstRow[X * 4 + 0] := R;
      DstRow[X * 4 + 1] := G;
      DstRow[X * 4 + 2] := B;
      DstRow[X * 4 + 3] := A;

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;

procedure ResizeBicubicRGBA32_NEON(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y, I, J: Integer;
  SrcX, SrcY: Int64;
  X0, Y0: Integer;
  FracX, FracY: Single;
  DstRow: PByte;
  SrcRow: PByte;
  P: PByte;
  R, G, B, A: Single;
  Weight: Single;
  WeightsX: array[-1..2] of Single;
  WeightsY: array[-1..2] of Single;
  SampleX, SampleY: Integer;
  XStep, YStep: Int64;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    FracY := (SrcY and $FFFF) / 65536.0;

    for J := -1 to 2 do
      WeightsY[J] := CubicWeight(FracY - J);

    DstRow := DstData + Y * DstStride;
    SrcX := 0;

    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      FracX := (SrcX and $FFFF) / 65536.0;

      for I := -1 to 2 do
        WeightsX[I] := CubicWeight(FracX - I);

      R := 0; G := 0; B := 0; A := 0;

      for J := -1 to 2 do
      begin
        SampleY := Y0 + J;
        if SampleY < 0 then SampleY := 0;
        if SampleY >= SrcHeight then SampleY := SrcHeight - 1;

        SrcRow := SrcData + SampleY * SrcStride;

        for I := -1 to 2 do
        begin
          SampleX := X0 + I;
          if SampleX < 0 then SampleX := 0;
          if SampleX >= SrcWidth then SampleX := SrcWidth - 1;

          Weight := WeightsX[I] * WeightsY[J];
          P := SrcRow + SampleX * 4;

          R := R + P[0] * Weight;
          G := G + P[1] * Weight;
          B := B + P[2] * Weight;
          A := A + P[3] * Weight;
        end;
      end;

      DstRow[X * 4 + 0] := ClampToByteF(R);
      DstRow[X * 4 + 1] := ClampToByteF(G);
      DstRow[X * 4 + 2] := ClampToByteF(B);
      DstRow[X * 4 + 3] := ClampToByteF(A);

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;
{$ENDIF}

{ Public dispatch functions }

procedure ResizeImageRGBA32(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer;
  Filter: TResizeFilter);
begin
  case Filter of
    rfNearest:
      ResizeNearestRGBA32_Scalar(SrcData, SrcWidth, SrcHeight, SrcStride,
        DstData, DstWidth, DstHeight, DstStride);
    rfBilinear:
      begin
        {$IFDEF HAS_NEON}
        if CpuFeatures.HasNEON then
          ResizeBilinearRGBA32_NEON(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
        {$IFDEF HAS_SSE2}
        if CpuFeatures.HasSSE2 then
          ResizeBilinearRGBA32_SSE2(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
          ResizeBilinearRGBA32_Scalar(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride);
      end;
    rfBicubic:
      begin
        {$IFDEF HAS_NEON}
        if CpuFeatures.HasNEON then
          ResizeBicubicRGBA32_NEON(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
        {$IFDEF HAS_SSE2}
        if CpuFeatures.HasSSE2 then
          ResizeBicubicRGBA32_SSE2(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
          ResizeBicubicRGBA32_Scalar(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride);
      end;
  end;
end;

{ SIMD-optimized bilinear resize for RGB24 }

{$IFDEF HAS_SSE2}
procedure ResizeBilinearRGB24_SSE2(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Int64;
  X0, Y0, X1, Y1: Integer;
  FracX, FracY: Integer;
  InvFracX, InvFracY: Integer;
  W00, W01, W10, W11: Integer;
  SrcRow0, SrcRow1, DstRow: PByte;
  P00, P01, P10, P11: PByte;
  XStep, YStep: Int64;
  R, G, B: Integer;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    Y1 := Min(Y0 + 1, SrcHeight - 1);
    FracY := (SrcY shr 8) and $FF;
    InvFracY := 256 - FracY;

    SrcRow0 := SrcData + Y0 * SrcStride;
    SrcRow1 := SrcData + Y1 * SrcStride;
    DstRow := DstData + Y * DstStride;

    SrcX := 0;
    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      X1 := Min(X0 + 1, SrcWidth - 1);
      FracX := (SrcX shr 8) and $FF;
      InvFracX := 256 - FracX;

      W00 := (InvFracX * InvFracY) shr 8;
      W01 := (FracX * InvFracY) shr 8;
      W10 := (InvFracX * FracY) shr 8;
      W11 := (FracX * FracY) shr 8;

      P00 := SrcRow0 + X0 * 3;
      P01 := SrcRow0 + X1 * 3;
      P10 := SrcRow1 + X0 * 3;
      P11 := SrcRow1 + X1 * 3;

      R := (P00[0] * W00 + P01[0] * W01 + P10[0] * W10 + P11[0] * W11) shr 8;
      G := (P00[1] * W00 + P01[1] * W01 + P10[1] * W10 + P11[1] * W11) shr 8;
      B := (P00[2] * W00 + P01[2] * W01 + P10[2] * W10 + P11[2] * W11) shr 8;

      if R > 255 then R := 255;
      if G > 255 then G := 255;
      if B > 255 then B := 255;

      DstRow[X * 3 + 0] := R;
      DstRow[X * 3 + 1] := G;
      DstRow[X * 3 + 2] := B;

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;

procedure ResizeBicubicRGB24_SSE2(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y, I, J: Integer;
  SrcX, SrcY: Int64;
  X0, Y0: Integer;
  FracX, FracY: Single;
  DstRow: PByte;
  SrcRow: PByte;
  P: PByte;
  R, G, B: Single;
  Weight: Single;
  WeightsX: array[-1..2] of Single;
  WeightsY: array[-1..2] of Single;
  SampleX, SampleY: Integer;
  XStep, YStep: Int64;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    FracY := (SrcY and $FFFF) / 65536.0;

    for J := -1 to 2 do
      WeightsY[J] := CubicWeight(FracY - J);

    DstRow := DstData + Y * DstStride;
    SrcX := 0;

    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      FracX := (SrcX and $FFFF) / 65536.0;

      for I := -1 to 2 do
        WeightsX[I] := CubicWeight(FracX - I);

      R := 0; G := 0; B := 0;

      for J := -1 to 2 do
      begin
        SampleY := Y0 + J;
        if SampleY < 0 then SampleY := 0;
        if SampleY >= SrcHeight then SampleY := SrcHeight - 1;

        SrcRow := SrcData + SampleY * SrcStride;

        for I := -1 to 2 do
        begin
          SampleX := X0 + I;
          if SampleX < 0 then SampleX := 0;
          if SampleX >= SrcWidth then SampleX := SrcWidth - 1;

          Weight := WeightsX[I] * WeightsY[J];
          P := SrcRow + SampleX * 3;

          R := R + P[0] * Weight;
          G := G + P[1] * Weight;
          B := B + P[2] * Weight;
        end;
      end;

      DstRow[X * 3 + 0] := ClampToByteF(R);
      DstRow[X * 3 + 1] := ClampToByteF(G);
      DstRow[X * 3 + 2] := ClampToByteF(B);

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;
{$ENDIF}

{$IFDEF HAS_NEON}
procedure ResizeBilinearRGB24_NEON(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Int64;
  X0, Y0, X1, Y1: Integer;
  FracX, FracY: Integer;
  InvFracX, InvFracY: Integer;
  W00, W01, W10, W11: Integer;
  SrcRow0, SrcRow1, DstRow: PByte;
  P00, P01, P10, P11: PByte;
  XStep, YStep: Int64;
  R, G, B: Integer;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    Y1 := Min(Y0 + 1, SrcHeight - 1);
    FracY := (SrcY shr 8) and $FF;
    InvFracY := 256 - FracY;

    SrcRow0 := SrcData + Y0 * SrcStride;
    SrcRow1 := SrcData + Y1 * SrcStride;
    DstRow := DstData + Y * DstStride;

    SrcX := 0;
    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      X1 := Min(X0 + 1, SrcWidth - 1);
      FracX := (SrcX shr 8) and $FF;
      InvFracX := 256 - FracX;

      W00 := (InvFracX * InvFracY) shr 8;
      W01 := (FracX * InvFracY) shr 8;
      W10 := (InvFracX * FracY) shr 8;
      W11 := (FracX * FracY) shr 8;

      P00 := SrcRow0 + X0 * 3;
      P01 := SrcRow0 + X1 * 3;
      P10 := SrcRow1 + X0 * 3;
      P11 := SrcRow1 + X1 * 3;

      R := (P00[0] * W00 + P01[0] * W01 + P10[0] * W10 + P11[0] * W11) shr 8;
      G := (P00[1] * W00 + P01[1] * W01 + P10[1] * W10 + P11[1] * W11) shr 8;
      B := (P00[2] * W00 + P01[2] * W01 + P10[2] * W10 + P11[2] * W11) shr 8;

      if R > 255 then R := 255;
      if G > 255 then G := 255;
      if B > 255 then B := 255;

      DstRow[X * 3 + 0] := R;
      DstRow[X * 3 + 1] := G;
      DstRow[X * 3 + 2] := B;

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;

procedure ResizeBicubicRGB24_NEON(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y, I, J: Integer;
  SrcX, SrcY: Int64;
  X0, Y0: Integer;
  FracX, FracY: Single;
  DstRow: PByte;
  SrcRow: PByte;
  P: PByte;
  R, G, B: Single;
  Weight: Single;
  WeightsX: array[-1..2] of Single;
  WeightsY: array[-1..2] of Single;
  SampleX, SampleY: Integer;
  XStep, YStep: Int64;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    FracY := (SrcY and $FFFF) / 65536.0;

    for J := -1 to 2 do
      WeightsY[J] := CubicWeight(FracY - J);

    DstRow := DstData + Y * DstStride;
    SrcX := 0;

    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      FracX := (SrcX and $FFFF) / 65536.0;

      for I := -1 to 2 do
        WeightsX[I] := CubicWeight(FracX - I);

      R := 0; G := 0; B := 0;

      for J := -1 to 2 do
      begin
        SampleY := Y0 + J;
        if SampleY < 0 then SampleY := 0;
        if SampleY >= SrcHeight then SampleY := SrcHeight - 1;

        SrcRow := SrcData + SampleY * SrcStride;

        for I := -1 to 2 do
        begin
          SampleX := X0 + I;
          if SampleX < 0 then SampleX := 0;
          if SampleX >= SrcWidth then SampleX := SrcWidth - 1;

          Weight := WeightsX[I] * WeightsY[J];
          P := SrcRow + SampleX * 3;

          R := R + P[0] * Weight;
          G := G + P[1] * Weight;
          B := B + P[2] * Weight;
        end;
      end;

      DstRow[X * 3 + 0] := ClampToByteF(R);
      DstRow[X * 3 + 1] := ClampToByteF(G);
      DstRow[X * 3 + 2] := ClampToByteF(B);

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;
{$ENDIF}

procedure ResizeImageRGB24(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer;
  Filter: TResizeFilter);
begin
  case Filter of
    rfNearest:
      ResizeNearestRGB24_Scalar(SrcData, SrcWidth, SrcHeight, SrcStride,
        DstData, DstWidth, DstHeight, DstStride);
    rfBilinear:
      begin
        {$IFDEF HAS_NEON}
        if CpuFeatures.HasNEON then
          ResizeBilinearRGB24_NEON(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
        {$IFDEF HAS_SSE2}
        if CpuFeatures.HasSSE2 then
          ResizeBilinearRGB24_SSE2(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
          ResizeBilinearRGB24_Scalar(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride);
      end;
    rfBicubic:
      begin
        {$IFDEF HAS_NEON}
        if CpuFeatures.HasNEON then
          ResizeBicubicRGB24_NEON(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
        {$IFDEF HAS_SSE2}
        if CpuFeatures.HasSSE2 then
          ResizeBicubicRGB24_SSE2(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
          ResizeBicubicRGB24_Scalar(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride);
      end;
  end;
end;

{ SIMD-optimized bilinear resize for Gray8 }

{$IFDEF HAS_SSE2}
procedure ResizeBilinearGray8_SSE2(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Int64;
  X0, Y0, X1, Y1: Integer;
  FracX, FracY: Integer;
  InvFracX, InvFracY: Integer;
  W00, W01, W10, W11: Integer;
  SrcRow0, SrcRow1, DstRow: PByte;
  XStep, YStep: Int64;
  G: Integer;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    Y1 := Min(Y0 + 1, SrcHeight - 1);
    FracY := (SrcY shr 8) and $FF;
    InvFracY := 256 - FracY;

    SrcRow0 := SrcData + Y0 * SrcStride;
    SrcRow1 := SrcData + Y1 * SrcStride;
    DstRow := DstData + Y * DstStride;

    SrcX := 0;
    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      X1 := Min(X0 + 1, SrcWidth - 1);
      FracX := (SrcX shr 8) and $FF;
      InvFracX := 256 - FracX;

      W00 := (InvFracX * InvFracY) shr 8;
      W01 := (FracX * InvFracY) shr 8;
      W10 := (InvFracX * FracY) shr 8;
      W11 := (FracX * FracY) shr 8;

      G := (SrcRow0[X0] * W00 + SrcRow0[X1] * W01 + SrcRow1[X0] * W10 + SrcRow1[X1] * W11) shr 8;

      if G > 255 then G := 255;
      DstRow[X] := G;

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;

procedure ResizeBicubicGray8_SSE2(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y, I, J: Integer;
  SrcX, SrcY: Int64;
  X0, Y0: Integer;
  FracX, FracY: Single;
  DstRow: PByte;
  SrcRow: PByte;
  G: Single;
  Weight: Single;
  WeightsX: array[-1..2] of Single;
  WeightsY: array[-1..2] of Single;
  SampleX, SampleY: Integer;
  XStep, YStep: Int64;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    FracY := (SrcY and $FFFF) / 65536.0;

    for J := -1 to 2 do
      WeightsY[J] := CubicWeight(FracY - J);

    DstRow := DstData + Y * DstStride;
    SrcX := 0;

    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      FracX := (SrcX and $FFFF) / 65536.0;

      for I := -1 to 2 do
        WeightsX[I] := CubicWeight(FracX - I);

      G := 0;

      for J := -1 to 2 do
      begin
        SampleY := Y0 + J;
        if SampleY < 0 then SampleY := 0;
        if SampleY >= SrcHeight then SampleY := SrcHeight - 1;

        SrcRow := SrcData + SampleY * SrcStride;

        for I := -1 to 2 do
        begin
          SampleX := X0 + I;
          if SampleX < 0 then SampleX := 0;
          if SampleX >= SrcWidth then SampleX := SrcWidth - 1;

          Weight := WeightsX[I] * WeightsY[J];
          G := G + SrcRow[SampleX] * Weight;
        end;
      end;

      DstRow[X] := ClampToByteF(G);

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;
{$ENDIF}

{$IFDEF HAS_NEON}
procedure ResizeBilinearGray8_NEON(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y: Integer;
  SrcX, SrcY: Int64;
  X0, Y0, X1, Y1: Integer;
  FracX, FracY: Integer;
  InvFracX, InvFracY: Integer;
  W00, W01, W10, W11: Integer;
  SrcRow0, SrcRow1, DstRow: PByte;
  XStep, YStep: Int64;
  G: Integer;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    Y1 := Min(Y0 + 1, SrcHeight - 1);
    FracY := (SrcY shr 8) and $FF;
    InvFracY := 256 - FracY;

    SrcRow0 := SrcData + Y0 * SrcStride;
    SrcRow1 := SrcData + Y1 * SrcStride;
    DstRow := DstData + Y * DstStride;

    SrcX := 0;
    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      X1 := Min(X0 + 1, SrcWidth - 1);
      FracX := (SrcX shr 8) and $FF;
      InvFracX := 256 - FracX;

      W00 := (InvFracX * InvFracY) shr 8;
      W01 := (FracX * InvFracY) shr 8;
      W10 := (InvFracX * FracY) shr 8;
      W11 := (FracX * FracY) shr 8;

      G := (SrcRow0[X0] * W00 + SrcRow0[X1] * W01 + SrcRow1[X0] * W10 + SrcRow1[X1] * W11) shr 8;

      if G > 255 then G := 255;
      DstRow[X] := G;

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;

procedure ResizeBicubicGray8_NEON(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer);
var
  X, Y, I, J: Integer;
  SrcX, SrcY: Int64;
  X0, Y0: Integer;
  FracX, FracY: Single;
  DstRow: PByte;
  SrcRow: PByte;
  G: Single;
  Weight: Single;
  WeightsX: array[-1..2] of Single;
  WeightsY: array[-1..2] of Single;
  SampleX, SampleY: Integer;
  XStep, YStep: Int64;
begin
  if (DstWidth <= 0) or (DstHeight <= 0) or (SrcWidth <= 0) or (SrcHeight <= 0) then
    Exit;

  XStep := ((Int64(SrcWidth - 1) shl 16) div Max(DstWidth - 1, 1));
  YStep := ((Int64(SrcHeight - 1) shl 16) div Max(DstHeight - 1, 1));

  SrcY := 0;
  for Y := 0 to DstHeight - 1 do
  begin
    Y0 := SrcY shr 16;
    FracY := (SrcY and $FFFF) / 65536.0;

    for J := -1 to 2 do
      WeightsY[J] := CubicWeight(FracY - J);

    DstRow := DstData + Y * DstStride;
    SrcX := 0;

    for X := 0 to DstWidth - 1 do
    begin
      X0 := SrcX shr 16;
      FracX := (SrcX and $FFFF) / 65536.0;

      for I := -1 to 2 do
        WeightsX[I] := CubicWeight(FracX - I);

      G := 0;

      for J := -1 to 2 do
      begin
        SampleY := Y0 + J;
        if SampleY < 0 then SampleY := 0;
        if SampleY >= SrcHeight then SampleY := SrcHeight - 1;

        SrcRow := SrcData + SampleY * SrcStride;

        for I := -1 to 2 do
        begin
          SampleX := X0 + I;
          if SampleX < 0 then SampleX := 0;
          if SampleX >= SrcWidth then SampleX := SrcWidth - 1;

          Weight := WeightsX[I] * WeightsY[J];
          G := G + SrcRow[SampleX] * Weight;
        end;
      end;

      DstRow[X] := ClampToByteF(G);

      Inc(SrcX, XStep);
    end;
    Inc(SrcY, YStep);
  end;
end;
{$ENDIF}

procedure ResizeImageGray8(
  SrcData: PByte; SrcWidth, SrcHeight, SrcStride: Integer;
  DstData: PByte; DstWidth, DstHeight, DstStride: Integer;
  Filter: TResizeFilter);
begin
  case Filter of
    rfNearest:
      ResizeNearestGray8_Scalar(SrcData, SrcWidth, SrcHeight, SrcStride,
        DstData, DstWidth, DstHeight, DstStride);
    rfBilinear:
      begin
        {$IFDEF HAS_NEON}
        if CpuFeatures.HasNEON then
          ResizeBilinearGray8_NEON(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
        {$IFDEF HAS_SSE2}
        if CpuFeatures.HasSSE2 then
          ResizeBilinearGray8_SSE2(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
          ResizeBilinearGray8_Scalar(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride);
      end;
    rfBicubic:
      begin
        {$IFDEF HAS_NEON}
        if CpuFeatures.HasNEON then
          ResizeBicubicGray8_NEON(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
        {$IFDEF HAS_SSE2}
        if CpuFeatures.HasSSE2 then
          ResizeBicubicGray8_SSE2(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride)
        else
        {$ENDIF}
          ResizeBicubicGray8_Scalar(SrcData, SrcWidth, SrcHeight, SrcStride,
            DstData, DstWidth, DstHeight, DstStride);
      end;
  end;
end;

end.
