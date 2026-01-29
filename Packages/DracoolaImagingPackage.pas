{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit DracoolaImagingPackage;

{$warn 5023 off : no warning about unused units}
interface

uses
  Imaging, ImagingBitmap, ImagingCanvases, ImagingClasses, ImagingDds,
  ImagingFormats, ImagingIO, ImagingJpeg, ImagingNetworkGraphics,
  ImagingTarga, ImagingTypes, ImagingUtility, ImagingPortableMaps, ImagingGif,
  ImagingColors, ImagingRadiance, ImagingQoi, ImagingMemory, ImagingSimd,
  ImagingSimdResize, ImagingThreadPool, libjpegturbo, zlibng_bindings,
  LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('DracoolaImagingPackage', @Register);
end.
