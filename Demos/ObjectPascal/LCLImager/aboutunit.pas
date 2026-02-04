unit AboutUnit;

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs, Buttons,
  ExtCtrls, StdCtrls, Imaging, DemoUtils;

type

  { TAboutForm }

  TAboutForm = class(TForm)
    BitBtn1: TBitBtn;
    ImageLogo: TImage;
    ImageLaz: TImage;
    LabGitHub: TLabel;
    LabImaging: TLabel;
    LabWeb: TLabel;
    LabVersion: TLabel;
    LabDemo: TLabel;
    procedure FormShow(Sender: TObject);
    procedure LabLinkClick(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end; 

var
  AboutForm: TAboutForm;

implementation

uses
  LCLIntf, LCLType,
  BGRABitmap, BGRABitmapTypes,
  ImagingTypes, ImagingClasses;

{$R *.lfm}

{ TAboutForm }

procedure TAboutForm.FormShow(Sender: TObject);
var
  Stream: TResourceStream;
  Image: TSingleImage;
  BGRA: TBGRABitmap;
  TempData: TImageData;
  X, Y: Integer;
  SrcPtr: PColor32Rec;
  DstPtr: PBGRAPixel;
begin
  LabVersion.Caption := 'version ' + Imaging.GetVersionStr;
  if ImageLogo.Picture.Graphic = nil then
  begin
    // Load logo from resource using Dracoola Imaging + BGRABitmap
    Stream := TResourceStream.Create(HInstance, 'LOGO', RT_RCDATA);
    try
      Image := TSingleImage.Create;
      try
        Image.LoadFromStream(Stream);

        // Convert to BGRA
        InitImage(TempData);
        try
          CloneImage(Image.ImageDataPointer^, TempData);
          ConvertImage(TempData, ifA8R8G8B8);

          BGRA := TBGRABitmap.Create(TempData.Width, TempData.Height);
          try
            SrcPtr := PColor32Rec(TempData.Bits);
            for Y := 0 to TempData.Height - 1 do
            begin
              DstPtr := BGRA.ScanLine[Y];
              for X := 0 to TempData.Width - 1 do
              begin
                DstPtr^.blue := SrcPtr^.B;
                DstPtr^.green := SrcPtr^.G;
                DstPtr^.red := SrcPtr^.R;
                DstPtr^.alpha := SrcPtr^.A;
                Inc(SrcPtr);
                Inc(DstPtr);
              end;
            end;
            BGRA.InvalidateBitmap;
            ImageLogo.Picture.Bitmap.Assign(BGRA.Bitmap);
          finally
            BGRA.Free;
          end;
        finally
          FreeImage(TempData);
        end;
      finally
        Image.Free;
      end;
    finally
      Stream.Free;
    end;
  end;
end;

procedure TAboutForm.LabLinkClick(Sender: TObject);
begin
  OpenURL(TLabel(Sender).Caption);
end;

end.

