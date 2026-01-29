{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit DracoolaImagingPackageExt;

{$warn 5023 off : no warning about unused units}
interface

uses
  ElderImagery, ElderImageryBsi, ElderImageryCif, ElderImageryImg,
  ElderImagerySky, ElderImageryTexture, ImagingBinary, ImagingCompare,
  ImagingExtFileFormats, ImagingJpeg2000, ImagingPcx, ImagingPsd, ImagingTiff,
  ImagingXpm, DracoolaImagingPackageExtRegister, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('DracoolaImagingPackageExtRegister',
    @DracoolaImagingPackageExtRegister.Register);
end;

initialization
  RegisterPackage('DracoolaImagingPackageExt', @Register);
end.
