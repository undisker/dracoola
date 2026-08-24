{
  Vampyre Imaging Library
  by Marek Mauder
  https://github.com/galfar/imaginglib
  https://imaginglib.sourceforge.io
  - - - - -
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0.
}

{ This unit contains image format loader/saver for JPEG 2000 images
  using OpenJPEG 2.x dynamic library.

  Supported platforms:
    Windows x64: openjp2.dll
    Linux x64: libopenjp2.so.7
    macOS x64/ARM64: libopenjp2.7.dylib
}
unit ImagingJpeg2000;

{$I ImagingOptions.inc}

interface

uses
  SysUtils, ImagingTypes, Imaging, ImagingColors, ImagingIO, ImagingUtility,
  ImagingExtFileFormats, OpenJpegDynLib;

type
  { Type Jpeg 2000 file (needed for OpenJPEG codec settings).}
  TJpeg2000FileType = (jtInvalid, jtJP2, jtJ2K, jtJPT);

  { Class for loading/saving Jpeg 2000 images. It uses OpenJPEG 2.x library
    loaded dynamically. Jpeg 2000 supports wide variety of data formats.
    You can have arbitrary number of components/channels, each with different
    bitdepth and optional "signedness". Jpeg 2000 images can be lossy or
    lossless compressed.

    Imaging can load most data formats (except images
    with component bitdepth > 16 => no Imaging data format equivalents).
    Components with sample separation are loaded correctly, ICC profiles
    or palettes are not used, YCbCr images are translated to RGB.

    You can set various options when saving Jpeg-2000 images. Look at
    properties of TJpeg2000FileFormat for details.}
  TJpeg2000FileFormat = class(TImageFileFormat)
  private
    FQuality: LongInt;
    FCodeStreamOnly: LongBool;
    FLosslessCompression: LongBool;
    FScaleOutput: LongBool;
    function GetFileType(Handle: TImagingHandle): TJpeg2000FileType;
  protected
    procedure Define; override;
    function LoadData(Handle: TImagingHandle; var Images: TDynImageDataArray;
      OnlyFirstLevel: Boolean): Boolean; override;
    function SaveData(Handle: TImagingHandle; const Images: TDynImageDataArray;
      Index: LongInt): Boolean; override;
    procedure ConvertToSupported(var Image: TImageData;
      const Info: TImageFormatInfo); override;
  public
    function TestFormat(Handle: TImagingHandle): Boolean; override;
    procedure CheckOptionsValidity; override;
  published
    { Controls JPEG 2000 lossy compression quality. It is number in range 1..100.
      1 means small/ugly file, 100 means large/nice file. Accessible trough
      ImagingJpeg2000Quality option. Default value is 80.}
    property Quality: LongInt read FQuality write FQuality;
    { Controls whether JPEG 2000 image is saved with full file headers or just
      as code stream. Default value is False. Accessible trough
      ImagingJpeg2000CodeStreamOnly option.}
    property CodeStreamOnly: LongBool read FCodeStreamOnly write FCodeStreamOnly;
    { Specifies JPEG 2000 image compression type. If True, saved JPEG 2000 files
      will be losslessly compressed. Otherwise lossy compression is used.
      Default value is False. Accessible trough
      ImagingJpeg2000LosslessCompression option.}
    property LosslessCompression: LongBool read FLosslessCompression write FLosslessCompression;
    { Specifies JPEG 2000 output scaling. Since JPEG 2000 supports arbitrary Bit Depths,
      the default behaviour is to scale the images up tp the next 8^n bit depth.
      This can be disabled by setting this option to False.
      Default value is True. Accessible through
      ImagingJpeg2000ScaleOutput option.}
    property ScaleOutput: LongBool read FScaleOutput write FScaleOutput;
  end;

implementation

const
  SJpeg2000FormatName = 'JPEG 2000 Image';
  SJpeg2000Masks      = '*.jp2,*.j2k,*.j2c,*.jpx,*.jpc';
  Jpeg2000SupportedFormats: TImageFormats = [ifGray8, ifGray16,
    ifA8Gray8, ifA16Gray16, ifR8G8B8, ifR16G16B16, ifA8R8G8B8, ifA16R16G16B16];
  Jpeg2000DefaultQuality = 80;
  Jpeg2000DefaultCodeStreamOnly = False;
  Jpeg2000DefaultLosslessCompression = False;
  Jpeg2000DefaultScaleOutput = True;

const
  JP2Signature: TChar8 = #0#0#0#$0C#$6A#$50#$20#$20;
  J2KSignature: TChar4 = #$FF#$4F#$FF#$51;

type
  TStreamWrapper = record
    IO: TIOFunctions;
    Handle: TImagingHandle;
    StartPos: Int64;
    Size: Int64;
  end;
  PStreamWrapper = ^TStreamWrapper;

{ Stream callback functions for OpenJPEG 2.x }

function StreamRead(p_buffer: Pointer; p_nb_bytes: OPJ_SIZE_T; p_user_data: Pointer): OPJ_SIZE_T; cdecl;
var
  Wrapper: PStreamWrapper;
begin
  Wrapper := PStreamWrapper(p_user_data);
  Result := Wrapper.IO.Read(Wrapper.Handle, p_buffer, p_nb_bytes);
  if Result = 0 then
    Result := OPJ_SIZE_T(-1); // EOF indicator
end;

function StreamWrite(p_buffer: Pointer; p_nb_bytes: OPJ_SIZE_T; p_user_data: Pointer): OPJ_SIZE_T; cdecl;
var
  Wrapper: PStreamWrapper;
begin
  Wrapper := PStreamWrapper(p_user_data);
  Result := Wrapper.IO.Write(Wrapper.Handle, p_buffer, p_nb_bytes);
end;

function StreamSkip(p_nb_bytes: OPJ_OFF_T; p_user_data: Pointer): OPJ_OFF_T; cdecl;
var
  Wrapper: PStreamWrapper;
begin
  Wrapper := PStreamWrapper(p_user_data);
  Result := Wrapper.IO.Seek(Wrapper.Handle, p_nb_bytes, smFromCurrent);
  if Result >= 0 then
    Result := p_nb_bytes
  else
    Result := -1;
end;

function StreamSeek(p_nb_bytes: OPJ_OFF_T; p_user_data: Pointer): OPJ_BOOL; cdecl;
var
  Wrapper: PStreamWrapper;
  NewPos: Int64;
begin
  Wrapper := PStreamWrapper(p_user_data);
  NewPos := Wrapper.IO.Seek(Wrapper.Handle, Wrapper.StartPos + p_nb_bytes, smFromBeginning);
  Result := (NewPos >= 0);
end;

procedure TJpeg2000FileFormat.Define;
begin
  inherited;
  FName := SJpeg2000FormatName;
  FFeatures := [ffLoad, ffSave];
  FSupportedFormats := Jpeg2000SupportedFormats;

  FQuality := Jpeg2000DefaultQuality;
  FCodeStreamOnly := Jpeg2000DefaultCodeStreamOnly;
  FLosslessCompression := Jpeg2000DefaultLosslessCompression;
  FScaleOutput := Jpeg2000DefaultScaleOutput;

  AddMasks(SJpeg2000Masks);
  RegisterOption(ImagingJpeg2000Quality, @FQuality);
  RegisterOption(ImagingJpeg2000CodeStreamOnly, @FCodeStreamOnly);
  RegisterOption(ImagingJpeg2000LosslessCompression, @FLosslessCompression);
  RegisterOption(ImagingJpeg2000ScaleOutput, @FScaleOutput);
end;

procedure TJpeg2000FileFormat.CheckOptionsValidity;
begin
  if not (FQuality in [1..100]) then
    FQuality := Jpeg2000DefaultQuality;
end;

function TJpeg2000FileFormat.GetFileType(Handle: TImagingHandle): TJpeg2000FileType;
var
  ReadCount: LongInt;
  Id: TChar8;
begin
  Result := jtInvalid;
  with GetIO do
  begin
    ReadCount := Read(Handle, @Id, SizeOf(Id));
    if ReadCount = SizeOf(Id) then
    begin
      if CompareMem(@Id, @JP2Signature, SizeOf(JP2Signature)) then
        Result := jtJP2
      else if CompareMem(@Id, @J2KSignature, SizeOf(J2KSignature)) then
        Result := jtJ2K;
    end;
    Seek(Handle, -ReadCount, smFromCurrent);
  end;
end;

function TJpeg2000FileFormat.LoadData(Handle: TImagingHandle;
  var Images: TDynImageDataArray; OnlyFirstLevel: Boolean): Boolean;
type
  TChannelInfo = record
    DestOffset: Integer;
    IsAlpha: Boolean;
    Shift: Integer;
    SrcMaxValue: Integer;
    DestMaxValue: Integer;
  end;
var
  FileType: TJpeg2000FileType;
  ChannelSize, I: Integer;
  Info: TImageFormatInfo;
  Codec: opj_codec_t;
  Stream: opj_stream_t;
  Parameters: opj_dparameters_t;
  Image: popj_image_t;
  Wrapper: TStreamWrapper;
  Channels: array of TChannelInfo;
  Format: TImageFormat;

  procedure WriteSample(Dest: PByte; AChannelSize, Value: Integer); {$IFDEF USE_INLINE}inline;{$ENDIF}
  begin
    case AChannelSize of
      1: Dest^ := Value;
      2: PWord(Dest)^ := Value;
      4: PUInt32(Dest)^ := Value;
    end;
  end;

  procedure CopySample(Src, Dest: PByte; AChannelSize: Integer); {$IFDEF USE_INLINE}inline;{$ENDIF}
  begin
    case AChannelSize of
      1: Dest^ := Src^;
      2: PWord(Dest)^ := PWord(Src)^;
      4: PUInt32(Dest)^ := PUInt32(Src)^;
    end;
  end;

  procedure ReadChannel(var Img: TImageData; const CInfo: TChannelInfo; const Comp: opj_image_comp; BytesPerPixel: Integer);
  var
    X, Y, SX, SY, SrcIdx, LineBytes: Integer;
    DestPtr, NewPtr, LineUpPtr: PByte;
    DontScaleSamples: Boolean;
  begin
    DontScaleSamples := (CInfo.SrcMaxValue = CInfo.DestMaxValue) or not FScaleOutput;
    LineBytes := Img.Width * BytesPerPixel;
    DestPtr := @PByteArray(Img.Bits)[CInfo.DestOffset];
    SrcIdx := 0;

    if (Comp.dx = 1) and (Comp.dy = 1) then
    begin
      for Y := 0 to Img.Height * Img.Width - 1 do
      begin
        if DontScaleSamples then
          WriteSample(DestPtr, ChannelSize, Comp.data[SrcIdx] + CInfo.Shift)
        else
          WriteSample(DestPtr, ChannelSize, MulDiv(Comp.data[SrcIdx] + CInfo.Shift, CInfo.DestMaxValue, CInfo.SrcMaxValue));

        Inc(SrcIdx);
        Inc(DestPtr, BytesPerPixel);
      end;
    end
    else
    begin
      for Y := 0 to Integer(Comp.h) - 1 do
      begin
        LineUpPtr := @PByteArray(Img.Bits)[Y * Integer(Comp.dy) * LineBytes + CInfo.DestOffset];
        DestPtr := LineUpPtr;

        for X := 0 to Integer(Comp.w) - 1 do
        begin
          if DontScaleSamples then
            WriteSample(DestPtr, ChannelSize, Comp.data[SrcIdx] + CInfo.Shift)
          else
            WriteSample(DestPtr, ChannelSize, MulDiv(Comp.data[SrcIdx] + CInfo.Shift, CInfo.DestMaxValue, CInfo.SrcMaxValue));

          NewPtr := DestPtr;

          for SX := 1 to Integer(Comp.dx) - 1 do
          begin
            if X * Integer(Comp.dx) + SX >= Img.Width then Break;
            Inc(NewPtr, BytesPerPixel);
            CopySample(DestPtr, NewPtr, ChannelSize);
          end;

          Inc(SrcIdx);
          Inc(DestPtr, BytesPerPixel * Integer(Comp.dx));
        end;

        for SY := 1 to Integer(Comp.dy) - 1 do
        begin
          if Y * Integer(Comp.dy) + SY >= Img.Height then Break;
          NewPtr := @PByteArray(Img.Bits)[(Y * Integer(Comp.dy) + SY) * LineBytes + CInfo.DestOffset];
          for X := 0 to Img.Width - 1 do
          begin
            CopySample(LineUpPtr, NewPtr, ChannelSize);
            Inc(LineUpPtr, BytesPerPixel);
            Inc(NewPtr, BytesPerPixel);
          end;
        end;
      end;
    end;
  end;

  procedure ConvertYCbCrToRGB(Pixels: PByte; NumPixels, BytesPerPixel: Integer);
  var
    J: Integer;
    PixPtr: PByte;
    CY, CB, CR: Byte;
    CYW, CBW, CRW: Word;
  begin
    PixPtr := Pixels;
    for J := 0 to NumPixels - 1 do
    begin
      if BytesPerPixel in [3, 4] then
      with PColor24Rec(PixPtr)^ do
      begin
        CY := R;
        CB := G;
        CR := B;
        YCbCrToRGB(CY, CB, CR, R, G, B);
      end
      else
      with PColor48Rec(PixPtr)^ do
      begin
        CYW := R;
        CBW := G;
        CRW := B;
        YCbCrToRGB16(CYW, CBW, CRW, R, G, B);
      end;
      Inc(PixPtr, BytesPerPixel);
    end;
  end;

begin
  Result := False;
  Image := nil;
  Stream := nil;
  Codec := nil;

  FileType := GetFileType(Handle);
  if FileType = jtInvalid then
    Exit;

  // Setup stream wrapper
  Wrapper.IO := GetIO;
  Wrapper.Handle := Handle;
  Wrapper.StartPos := Wrapper.IO.Tell(Handle);
  Wrapper.Size := ImagingIO.GetInputSize(Wrapper.IO, Handle);

  // Create codec based on file type
  case FileType of
    jtJP2: Codec := opj_create_decompress(OPJ_CODEC_JP2);
    jtJ2K: Codec := opj_create_decompress(OPJ_CODEC_J2K);
    jtJPT: Codec := opj_create_decompress(OPJ_CODEC_JPT);
  else
    Exit;
  end;

  if Codec = nil then
    Exit;

  try
    // Setup decoder parameters
    opj_set_default_decoder_parameters(@Parameters);
    if not opj_setup_decoder(Codec, @Parameters) then
      Exit;

    // Create stream
    Stream := opj_stream_create(OPJ_J2K_STREAM_CHUNK_SIZE, OPJ_TRUE);
    if Stream = nil then
      Exit;

    opj_stream_set_read_function(Stream, @StreamRead);
    opj_stream_set_skip_function(Stream, @StreamSkip);
    opj_stream_set_seek_function(Stream, @StreamSeek);
    opj_stream_set_user_data(Stream, @Wrapper, nil);
    opj_stream_set_user_data_length(Stream, Wrapper.Size);

    // Read header
    if not opj_read_header(Stream, Codec, @Image) then
      Exit;

    if Image = nil then
      Exit;

    // Decode the image
    if not opj_decode(Codec, Stream, Image) then
      Exit;

    opj_end_decompress(Codec, Stream);

    // Determine which Imaging data format to use
    Format := ifUnknown;
    case Image.numcomps of
      2: case Image.comps[0].prec of
            1..8: Format := ifA8Gray8;
           9..16: Format := ifA16Gray16;
         end;
      3: case Image.comps[0].prec of
            1..8: Format := ifR8G8B8;
           9..16: Format := ifR16G16B16;
         end;
      4: case Image.comps[0].prec of
            1..8: Format := ifA8R8G8B8;
           9..16: Format := ifA16R16G16B16;
         end;
    else
      case Image.comps[0].prec of
           1..8: Format := ifGray8;
          9..16: Format := ifGray16;
         17..32: Format := ifGray32;
       end;
    end;

    if Format = ifUnknown then
      Exit;

    SetLength(Images, 1);
    NewImage(Image.x1 - Image.x0, Image.y1 - Image.y0, Format, Images[0]);
    Info := GetFormatInfo(Format);
    ChannelSize := Info.BytesPerPixel div Info.ChannelCount;
    SetLength(Channels, Info.ChannelCount);

    // Get information about all channels/components
    for I := 0 to Info.ChannelCount - 1 do
    begin
      Channels[I].IsAlpha := Image.comps[I].alpha <> 0;

      if Channels[I].IsAlpha then
        Channels[I].DestOffset := Info.ChannelCount - 1
      else if Info.ChannelCount <= 2 then
        // Grayscale
        Channels[I].DestOffset := 0
      else
      begin
        // RGB - OpenJPEG stores in RGB order, we need BGR
        case I of
          0: Channels[I].DestOffset := 2; // R -> offset 2
          1: Channels[I].DestOffset := 1; // G -> offset 1
          2: Channels[I].DestOffset := 0; // B -> offset 0
          3: Channels[I].DestOffset := 3; // A -> offset 3
        else
          Channels[I].DestOffset := I;
        end;
      end;

      Channels[I].DestOffset := Channels[I].DestOffset * ChannelSize;

      if Image.comps[I].sgnd <> 0 then
        Channels[I].Shift := 1 shl (Image.comps[I].prec - 1)
      else
        Channels[I].Shift := 0;

      Channels[I].SrcMaxValue := (1 shl Image.comps[I].prec) - 1;
      Channels[I].DestMaxValue := (1 shl (ChannelSize * 8)) - 1;
    end;

    // Read all channels
    for I := 0 to Info.ChannelCount - 1 do
      ReadChannel(Images[0], Channels[I], Image.comps[I], Info.BytesPerPixel);

    // Convert YCbCr to RGB if needed
    if (Image.color_space = OPJ_CLRSPC_SYCC) and (Info.ChannelCount in [3, 4]) then
      ConvertYCbCrToRGB(Images[0].Bits, Images[0].Width * Images[0].Height, Info.BytesPerPixel);

    Result := True;
  finally
    if Image <> nil then
      opj_image_destroy(Image);
    if Stream <> nil then
      opj_stream_destroy(Stream);
    if Codec <> nil then
      opj_destroy_codec(Codec);
  end;
end;

function TJpeg2000FileFormat.SaveData(Handle: TImagingHandle;
  const Images: TDynImageDataArray; Index: LongInt): Boolean;
var
  TargetSize, Rate: Single;
  ImageToSave: TImageData;
  MustBeFreed: Boolean;
  Info: TImageFormatInfo;
  I, Z, InvZ, Channel, ChannelSize, NumPixels: Integer;
  Pix: PByte;
  Image: popj_image_t;
  Stream: opj_stream_t;
  Codec: opj_codec_t;
  Parameters: opj_cparameters_t;
  CompParams: array of opj_image_cmptparm_t;
  ColorSpace: OPJ_COLOR_SPACE;
  Wrapper: TStreamWrapper;
begin
  Result := False;
  Image := nil;
  Stream := nil;
  Codec := nil;

  if MakeCompatible(Images[Index], ImageToSave, MustBeFreed) then
  try
    Info := GetFormatInfo(ImageToSave.Format);
    ChannelSize := Info.BytesPerPixel div Info.ChannelCount;

    // Fill component parameters
    SetLength(CompParams, Info.ChannelCount);
    for I := 0 to Info.ChannelCount - 1 do
    begin
      CompParams[I].dx := 1;
      CompParams[I].dy := 1;
      CompParams[I].w := ImageToSave.Width;
      CompParams[I].h := ImageToSave.Height;
      CompParams[I].prec := ChannelSize * 8;
      CompParams[I].bpp := CompParams[I].prec;
      CompParams[I].sgnd := 0;
      CompParams[I].x0 := 0;
      CompParams[I].y0 := 0;
    end;

    if Info.HasGrayChannel then
      ColorSpace := OPJ_CLRSPC_GRAY
    else
      ColorSpace := OPJ_CLRSPC_SRGB;

    Image := opj_image_create(Info.ChannelCount, @CompParams[0], ColorSpace);
    if Image = nil then
      Exit;

    Image.x0 := 0;
    Image.y0 := 0;
    Image.x1 := ImageToSave.Width;
    Image.y1 := ImageToSave.Height;

    // Mark alpha channel
    if Info.HasAlphaChannel then
      Image.comps[Info.ChannelCount - 1].alpha := 1;

    // Create codec
    if FCodeStreamOnly then
      Codec := opj_create_compress(OPJ_CODEC_J2K)
    else
      Codec := opj_create_compress(OPJ_CODEC_JP2);

    if Codec = nil then
      Exit;

    // Set compression parameters
    opj_set_default_encoder_parameters(@Parameters);
    Parameters.numresolution := 6;
    Parameters.tcp_numlayers := 1;
    Parameters.cp_disto_alloc := 1;

    if FLosslessCompression then
    begin
      Parameters.tcp_rates[0] := 0;
    end
    else
    begin
      Rate := 100.0 / Sqr(115 - FQuality);
      NumPixels := ImageToSave.Width * ImageToSave.Height * Info.BytesPerPixel;
      TargetSize := (NumPixels * Rate) + 550 + (Info.ChannelCount - 1) * 142;
      Parameters.tcp_rates[0] := 1.0 / (TargetSize / NumPixels);
    end;

    if not opj_setup_encoder(Codec, @Parameters, Image) then
      Exit;

    // Fill component data
    for Channel := 0 to Info.ChannelCount - 1 do
    begin
      Z := Channel;
      InvZ := Info.ChannelCount - 1 - Z;
      if Info.HasAlphaChannel then
      begin
        if Channel = Info.ChannelCount - 1 then
          InvZ := Z
        else
          InvZ := Info.ChannelCount - 2 - Z;
      end;
      Pix := @PByteArray(ImageToSave.Bits)[InvZ * ChannelSize];
      for I := 0 to ImageToSave.Width * ImageToSave.Height - 1 do
      begin
        case ChannelSize of
          1: Image.comps[Z].data[I] := Pix^;
          2: Image.comps[Z].data[I] := PWord(Pix)^;
          4: OPJ_UINT32(Image.comps[Z].data[I]) := PUInt32(Pix)^;
        end;
        Inc(Pix, Info.BytesPerPixel);
      end;
    end;

    // Setup stream wrapper for writing
    Wrapper.IO := GetIO;
    Wrapper.Handle := Handle;
    Wrapper.StartPos := Wrapper.IO.Tell(Handle);
    Wrapper.Size := 0;

    // Create output stream
    Stream := opj_stream_create(OPJ_J2K_STREAM_CHUNK_SIZE, OPJ_FALSE);
    if Stream = nil then
      Exit;

    opj_stream_set_write_function(Stream, @StreamWrite);
    opj_stream_set_skip_function(Stream, @StreamSkip);
    opj_stream_set_seek_function(Stream, @StreamSeek);
    opj_stream_set_user_data(Stream, @Wrapper, nil);

    // Encode
    if not opj_start_compress(Codec, Image, Stream) then
      Exit;

    if not opj_encode(Codec, Stream) then
      Exit;

    if not opj_end_compress(Codec, Stream) then
      Exit;

    Result := True;
  finally
    if MustBeFreed then
      FreeImage(ImageToSave);
    if Image <> nil then
      opj_image_destroy(Image);
    if Stream <> nil then
      opj_stream_destroy(Stream);
    if Codec <> nil then
      opj_destroy_codec(Codec);
  end;
end;

procedure TJpeg2000FileFormat.ConvertToSupported(var Image: TImageData;
  const Info: TImageFormatInfo);
var
  ConvFormat: TImageFormat;
begin
  if Info.IsFloatingPoint then
    ConvFormat := IffFormat(Info.ChannelCount = 1, ifGray16, ifA16R16G16B16)
  else if Info.HasGrayChannel then
    ConvFormat := IffFormat(Info.HasAlphaChannel, ifA16Gray16, ifGray16)
  else if Info.IsIndexed then
    ConvFormat := ifA8R8G8B8
  else if Info.BytesPerPixel div Info.ChannelCount > 1 then
    ConvFormat := IffFormat(Info.HasAlphaChannel, ifA16R16G16B16, ifR16G16B16)
  else
    ConvFormat := IffFormat(Info.HasAlphaChannel, ifA8R8G8B8, ifR8G8B8);

  ConvertImage(Image, ConvFormat);
end;

function TJpeg2000FileFormat.TestFormat(Handle: TImagingHandle): Boolean;
begin
  Result := False;
  if Handle <> nil then
    Result := GetFileType(Handle) <> jtInvalid;
end;

initialization
  // Only register the format if the dynamic library loads successfully
  if LoadOpenJpegLibrary then
    RegisterImageFileFormat(TJpeg2000FileFormat);

{
  File Notes:

 -- TODOS ----------------------------------------------------
    - nothing now

  -- 0.80 Changes ---------------------------------------------
    - Migrated to OpenJPEG 2.x API with dynamic library loading
    - Removed platform restrictions - now works on all platforms
      where OpenJPEG 2.x library is available
    - Removed static object file linking

  -- 0.27 Changes ---------------------------------------------
    - by Hanno Hugenberg <hanno.hugenberg@pergamonmed.com>
    - introduced the ImagingJpeg2000ScaleOutput parameter for keeping
      the original decoded images by avoiding upscaling of output images

  -- 0.26.3 Changes/Bug Fixes -----------------------------------
    - Rewritten JP2 loading part (based on PasJpeg2000) to be
      more readable (it's a bit faster too) and handled more JP2 files better:
      components with precisions like 12bit (not direct Imaging equivalent)
      are properly scaled, images/components with offsets are loaded ok.

  -- 0.24.3 Changes/Bug Fixes -----------------------------------
    - Alpha channels are now saved properly in FPC (GCC optimization issue),
      FPC lossy compression enabled again!
    - Added handling of component types (CDEF Box), JP2 images with alpha
      are now properly recognized by other applications.
    - Fixed wrong color space when saving grayscale images

  -- 0.21 Changes/Bug Fixes -----------------------------------
    - Removed ifGray32 from supported formats, OpenJPEG crashes when saving them.
    - Added Seek after loading to set input pos to the end of image.
    - Saving added lossy/lossless, quality option added.
    - Initial loading-only version created.

}
end.
