{
  Dracoola Imaging Library
  by Marek Mauder
  https://github.com/galfar/imaginglib
  https://imaginglib.sourceforge.io
  - - - - -
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0.
}

{ This unit contains image format loader/saver for Jpeg images.
  Uses TurboJPEG API from libjpeg-turbo for SIMD-accelerated JPEG
  compression/decompression.

  The TurboJPEG API is simpler and more robust than the legacy libjpeg API,
  with no complex C struct alignment issues. }
unit ImagingJpeg;

{$I ImagingOptions.inc}

interface

uses
  SysUtils, ImagingTypes, Imaging, ImagingColors,
  turbojpegapi,
  ImagingUtility;

type
  { Class for loading/saving Jpeg images. Supports load/save of
    8 bit grayscale and 24 bit RGB images. Jpegs can be saved with optional
    progressive encoding.
    Based on TurboJPEG API for SIMD-accelerated compression/decompression. }
  TJpegFileFormat = class(TImageFileFormat)
  private
    FGrayScale: Boolean;
  protected
    FQuality: LongInt;
    FProgressive: LongBool;
    procedure SetJpegIO(const JpegIO: TIOFunctions); virtual;
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
    { Controls Jpeg save compression quality. It is number in range 1..100.
      1 means small/ugly file, 100 means large/nice file. Accessible through
      ImagingJpegQuality option.}
    property Quality: LongInt read FQuality write FQuality;
    { If True Jpeg images are saved in progressive format. Accessible through
      ImagingJpegProgressive option.}
    property Progressive: LongBool read FProgressive write FProgressive;
  end;

implementation

const
  SJpegFormatName = 'Joint Photographic Experts Group Image';
  SJpegMasks      = '*.jpg,*.jpeg,*.jfif,*.jpe,*.jif';
  JpegSupportedFormats: TImageFormats = [ifR8G8B8, ifGray8];
  JpegDefaultQuality = 90;
  JpegDefaultProgressive = False;

const
  { Jpeg file identifiers.}
  JpegMagic: TChar2 = #$FF#$D8;

resourcestring
  SJpegError = 'JPEG Error';
  SJpegLibraryNotLoaded = 'TurboJPEG library (turbojpeg.dll) not loaded';

{ TJpegFileFormat class implementation }

procedure TJpegFileFormat.Define;
begin
  FName := SJpegFormatName;
  FFeatures := [ffLoad, ffSave];
  FSupportedFormats := JpegSupportedFormats;

  FQuality := JpegDefaultQuality;
  FProgressive := JpegDefaultProgressive;

  AddMasks(SJpegMasks);
  RegisterOption(ImagingJpegQuality, @FQuality);
  RegisterOption(ImagingJpegProgressive, @FProgressive);
end;

procedure TJpegFileFormat.CheckOptionsValidity;
begin
  // Check if option values are valid
  if not (FQuality in [1..100]) then
    FQuality := JpegDefaultQuality;
end;

function TJpegFileFormat.LoadData(Handle: TImagingHandle;
  var Images: TDynImageDataArray; OnlyFirstLevel: Boolean): Boolean;
var
  JpegHandle: tjhandle;
  JpegBuf: PByte;
  JpegSize: NativeUInt;
  Width, Height, Subsamp, Colorspace: Integer;
  PixFmt: TJPF;
  Info: TImageFormatInfo;
  IO: TIOFunctions;
  StartPos, FileSize: Int64;
  I: Integer;
  Col32: PColor32Rec;
begin
  Result := False;

  // Check if library is loaded
  if not IsTurboJpegLibraryLoaded then
    raise EImagingError.Create(SJpegLibraryNotLoaded);

  IO := GetIO;
  SetLength(Images, 1);

  // Read entire JPEG into memory buffer
  StartPos := IO.Tell(Handle);
  IO.Seek(Handle, 0, smFromEnd);
  FileSize := IO.Tell(Handle) - StartPos;
  IO.Seek(Handle, StartPos, smFromBeginning);

  JpegBuf := GetMem(FileSize);
  JpegHandle := nil;
  try
    IO.Read(Handle, JpegBuf, FileSize);
    JpegSize := FileSize;

    // Create TurboJPEG decompressor instance
    JpegHandle := tj3Init(Ord(TJINIT_DECOMPRESS));
    if JpegHandle = nil then
      raise EImagingError.Create(SJpegError + ': Failed to initialize decompressor');

    // Read JPEG header
    if tj3DecompressHeader(JpegHandle, JpegBuf, JpegSize) <> 0 then
      raise EImagingError.CreateFmt(SJpegError + ': %s', [string(tj3GetErrorStr(JpegHandle))]);

    // Get image dimensions and format
    Width := tj3Get(JpegHandle, Ord(TJPARAM_JPEGWIDTH));
    Height := tj3Get(JpegHandle, Ord(TJPARAM_JPEGHEIGHT));
    Subsamp := tj3Get(JpegHandle, Ord(TJPARAM_SUBSAMP));
    Colorspace := tj3Get(JpegHandle, Ord(TJPARAM_COLORSPACE));

    // Determine output format based on colorspace
    if Colorspace = Ord(TJCS_GRAY) then
    begin
      Images[0].Format := ifGray8;
      PixFmt := TJPF_GRAY;
    end
    else if Colorspace = Ord(TJCS_CMYK) then
    begin
      // CMYK will be decompressed as CMYK, then converted to RGB
      Images[0].Format := ifA8R8G8B8;
      PixFmt := TJPF_CMYK;
    end
    else
    begin
      // All other colorspaces decompress to RGB
      Images[0].Format := ifR8G8B8;
      PixFmt := TJPF_RGB;
    end;

    // Allocate image
    NewImage(Width, Height, Images[0].Format, Images[0]);
    GetImageFormatInfo(Images[0].Format, Info);

    // Decompress JPEG to image buffer
    if tj3Decompress8(JpegHandle, JpegBuf, JpegSize,
      Images[0].Bits, Width * Info.BytesPerPixel, Ord(PixFmt)) <> 0 then
      raise EImagingError.CreateFmt(SJpegError + ': %s', [string(tj3GetErrorStr(JpegHandle))]);

    // Convert CMYK to RGB if needed
    if Colorspace = Ord(TJCS_CMYK) then
    begin
      Col32 := Images[0].Bits;
      for I := 0 to Width * Height - 1 do
      begin
        // TurboJPEG returns CMYK in order C, M, Y, K stored in R, G, B, A
        CMYKToRGB(255 - Col32.R, 255 - Col32.G, 255 - Col32.B, 255 - Col32.A,
          Col32.R, Col32.G, Col32.B);
        Col32.A := 255;
        Inc(Col32);
      end;
    end;

    Result := True;
  finally
    if JpegHandle <> nil then
      tj3Destroy(JpegHandle);
    FreeMem(JpegBuf);
  end;
end;

function TJpegFileFormat.SaveData(Handle: TImagingHandle;
  const Images: TDynImageDataArray; Index: LongInt): Boolean;
var
  JpegHandle: tjhandle;
  JpegBuf: PByte;
  JpegSize: NativeUInt;
  ImageToSave: TImageData;
  Info: TImageFormatInfo;
  MustBeFreed: Boolean;
  PixFmt: TJPF;
  Subsamp: TJSAMP;
  IO: TIOFunctions;
begin
  Result := False;

  // Check if library is loaded
  if not IsTurboJpegLibraryLoaded then
    raise EImagingError.Create(SJpegLibraryNotLoaded);

  IO := GetIO;

  // Makes image to save compatible with Jpeg saving capabilities
  if MakeCompatible(Images[Index], ImageToSave, MustBeFreed) then
  begin
    JpegHandle := nil;
    JpegBuf := nil;
    try
      GetImageFormatInfo(ImageToSave.Format, Info);
      FGrayScale := ImageToSave.Format = ifGray8;

      // Create TurboJPEG compressor instance
      JpegHandle := tj3Init(Ord(TJINIT_COMPRESS));
      if JpegHandle = nil then
        raise EImagingError.Create(SJpegError + ': Failed to initialize compressor');

      // Set compression parameters
      tj3Set(JpegHandle, Ord(TJPARAM_QUALITY), FQuality);

      if FProgressive then
        tj3Set(JpegHandle, Ord(TJPARAM_PROGRESSIVE), 1);

      // Determine pixel format and subsampling
      if FGrayScale then
      begin
        PixFmt := TJPF_GRAY;
        Subsamp := TJSAMP_GRAY;
      end
      else
      begin
        PixFmt := TJPF_RGB;
        Subsamp := TJSAMP_420; // 4:2:0 subsampling for best compression
      end;

      tj3Set(JpegHandle, Ord(TJPARAM_SUBSAMP), Ord(Subsamp));

      // Compress image
      JpegSize := 0;
      if tj3Compress8(JpegHandle, ImageToSave.Bits, ImageToSave.Width,
        ImageToSave.Width * Info.BytesPerPixel, ImageToSave.Height,
        Ord(PixFmt), JpegBuf, JpegSize) <> 0 then
        raise EImagingError.CreateFmt(SJpegError + ': %s', [string(tj3GetErrorStr(JpegHandle))]);

      // Write compressed data to output
      IO.Write(Handle, JpegBuf, JpegSize);

      Result := True;
    finally
      if JpegBuf <> nil then
        tj3Free(JpegBuf);
      if JpegHandle <> nil then
        tj3Destroy(JpegHandle);
      if MustBeFreed then
        FreeImage(ImageToSave);
    end;
  end;
end;

procedure TJpegFileFormat.ConvertToSupported(var Image: TImageData;
  const Info: TImageFormatInfo);
begin
  if Info.HasGrayChannel then
    ConvertImage(Image, ifGray8)
  else
    ConvertImage(Image, ifR8G8B8);
end;

function TJpegFileFormat.TestFormat(Handle: TImagingHandle): Boolean;
var
  ReadCount: LongInt;
  ID: array[0..9] of AnsiChar;
begin
  Result := False;
  if Handle <> nil then
  with GetIO do
  begin
    FillChar(ID, SizeOf(ID), 0);
    ReadCount := Read(Handle, @ID, SizeOf(ID));
    Seek(Handle, -ReadCount, smFromCurrent);
    Result := (ReadCount = SizeOf(ID)) and
      CompareMem(@ID, @JpegMagic, SizeOf(JpegMagic));
  end;
end;

procedure TJpegFileFormat.SetJpegIO(const JpegIO: TIOFunctions);
begin
  // This method is kept for API compatibility with TCustomIOJpegFileFormat
  // in ImagingNetworkGraphics. The TurboJPEG implementation reads the entire
  // stream into memory, so custom IO is not needed.
  // Subclasses can override this if needed.
end;

initialization
  RegisterImageFileFormat(TJpegFileFormat);

{
  File Notes:

 -- TODOS ----------------------------------------------------
    - Add ICC profile support via tj3GetICCProfile/tj3SetICCProfile
    - Add scaling support for large images

  -- TurboJPEG API Migration -----------------------------------------
    - Completely rewrote to use TurboJPEG API (tj3* functions)
    - TurboJPEG API is simpler, has no C struct alignment issues
    - Better error handling with descriptive error messages
    - Memory is managed by TurboJPEG (tj3Alloc/tj3Free)
    - Removed all complex libjpeg v6 struct definitions
    - Removed source/destination manager callbacks
    - Removed setjmp/longjmp error recovery (TurboJPEG handles this)

  -- FreePascal Fork -----------------------------------------
    - Converted to use libjpeg-turbo for SIMD-accelerated JPEG processing
    - Removed Delphi-specific code
    - Removed bundled JpegLib dependency

  -- 0.77.1 ---------------------------------------------------
    - Able to read corrupted JPEG files - loads partial image
      and skips the corrupted parts (FPC and x86 Delphi).
    - Fixed reading of physical resolution metadata, could cause
      "divided by zero" later on for some files.

  -- 0.26.5 Changes/Bug Fixes ---------------------------------
    - Fixed loading of some JPEGs with certain APPN markers (bug in JpegLib).
    - Fixed swapped Red-Blue order when loading Jpegs with
      jc.d.jpeg_color_space = JCS_RGB.
    - Added loading and saving of physical pixel size metadata.

  -- 0.26.3 Changes/Bug Fixes ---------------------------------
    - Changed the Jpeg error manager, messages were not properly formatted.

  -- 0.26.1 Changes/Bug Fixes ---------------------------------
    - Fixed wrong color space setting in InitCompressor.
    - Fixed problem with progressive Jpegs in FPC (modified JpegLib,
      can't use FPC's PasJpeg in Windows).

  -- 0.25.0 Changes/Bug Fixes ---------------------------------
    - FPC's PasJpeg wasn't really used in last version, fixed.

  -- 0.24.1 Changes/Bug Fixes ---------------------------------
    - Fixed loading of CMYK jpeg images. Could cause heap corruption
      and loaded image looked wrong.

  -- 0.23 Changes/Bug Fixes -----------------------------------
    - Removed JFIF/EXIF detection from TestFormat. Found JPEGs
      with different headers (Lavc) which weren't recognized.

  -- 0.21 Changes/Bug Fixes -----------------------------------
    - MakeCompatible method moved to base class, put ConvertToSupported here.
      GetSupportedFormats removed, it is now set in constructor.
    - Made public properties for options registered to SetOption/GetOption
      functions.
    - Changed extensions to filename masks.
    - Changed SaveData, LoadData, and MakeCompatible methods according
      to changes in base class in Imaging unit.
    - Changes in TestFormat, now reads JFIF and EXIF signatures too.

  -- 0.19 Changes/Bug Fixes -----------------------------------
    - input position is now set correctly to the end of the image
      after loading is done. Loading of sequence of JPEG files stored in
      single stream works now
    - when loading and saving images in FPC with PASJPEG read and
      blue channels are swapped to have the same chanel order as IMJPEGLIB
    - you can now choose between IMJPEGLIB and PASJPEG implementations

  -- 0.17 Changes/Bug Fixes -----------------------------------
    - added SetJpegIO method which is used by JNG image format
}
end.
