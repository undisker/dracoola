unit MainForm;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Menus, ExtDlgs, FileUtil, LCLType, Math,
  BGRABitmap, BGRABitmapTypes,
  ImagingTypes, Imaging, ImagingClasses, ImagingUtility;

type
  { TFormMain }
  TFormMain = class(TForm)
    MainMenu: TMainMenu;
    MenuFile: TMenuItem;
    MenuOpen: TMenuItem;
    MenuSep1: TMenuItem;
    MenuExit: TMenuItem;
    MenuView: TMenuItem;
    MenuFitToWindow: TMenuItem;
    MenuActualSize: TMenuItem;
    MenuSep2: TMenuItem;
    MenuImageInfo: TMenuItem;
    MenuHelp: TMenuItem;
    MenuAbout: TMenuItem;
    OpenDialog: TOpenPictureDialog;
    PanelTop: TPanel;
    LabelInfo: TLabel;
    PanelMain: TPanel;
    ScrollBox: TScrollBox;
    PaintBox: TPaintBox;
    StatusBar: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of String);
    procedure MenuOpenClick(Sender: TObject);
    procedure MenuExitClick(Sender: TObject);
    procedure MenuFitToWindowClick(Sender: TObject);
    procedure MenuActualSizeClick(Sender: TObject);
    procedure MenuImageInfoClick(Sender: TObject);
    procedure MenuAboutClick(Sender: TObject);
    procedure PaintBoxPaint(Sender: TObject);
    procedure ScrollBoxResize(Sender: TObject);
  private
    FImage: TSingleImage;           // Dracoola image for loading
    FBGRABitmap: TBGRABitmap;       // BGRABitmap for display
    FFileName: string;
    FFitToWindow: Boolean;
    FLoadTimeMs: Double;
    FConvertTimeMs: Double;
    procedure LoadImage(const AFileName: string);
    procedure ConvertToBGRA;
    procedure UpdateView;
    procedure UpdateStatusBar;
    function GetOpenFilter: string;
  public
  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}

function FormatByteSize(Bytes: Int64): string;
begin
  if Bytes < 1024 then
    Result := Format('%d B', [Bytes])
  else if Bytes < 1024 * 1024 then
    Result := Format('%.1f KB', [Bytes / 1024])
  else
    Result := Format('%.1f MB', [Bytes / (1024 * 1024)]);
end;

{ TFormMain }

procedure TFormMain.FormCreate(Sender: TObject);
var
  DataPath: string;
begin
  Caption := 'BGRA Image Viewer - Vampyre Imaging Library';
  FImage := TSingleImage.Create;
  FBGRABitmap := TBGRABitmap.Create(1, 1);
  FFitToWindow := True;
  MenuFitToWindow.Checked := True;

  // Set up open dialog filter with all supported formats
  OpenDialog.Filter := GetOpenFilter;

  // Find data path - try various relative paths
  DataPath := '';
  if FileExists('..\..\Data\Tigers.jpg') then
    DataPath := '..\..\Data\'
  else if FileExists('..\..\..\Demos\Data\Tigers.jpg') then
    DataPath := '..\..\..\Demos\Data\'
  else if FileExists('..\..\..\..\Demos\Data\Tigers.jpg') then
    DataPath := '..\..\..\..\Demos\Data\';

  // Load default image if exists
  if DataPath <> '' then
    LoadImage(DataPath + 'Tigers.jpg');
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FBGRABitmap.Free;
  FImage.Free;
end;

procedure TFormMain.FormDropFiles(Sender: TObject; const FileNames: array of String);
begin
  if Length(FileNames) > 0 then
    LoadImage(FileNames[0]);
end;

procedure TFormMain.MenuOpenClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    LoadImage(OpenDialog.FileName);
end;

procedure TFormMain.MenuExitClick(Sender: TObject);
begin
  Close;
end;

procedure TFormMain.MenuFitToWindowClick(Sender: TObject);
begin
  FFitToWindow := True;
  MenuFitToWindow.Checked := True;
  MenuActualSize.Checked := False;
  UpdateView;
end;

procedure TFormMain.MenuActualSizeClick(Sender: TObject);
begin
  FFitToWindow := False;
  MenuFitToWindow.Checked := False;
  MenuActualSize.Checked := True;
  UpdateView;
end;

procedure TFormMain.MenuImageInfoClick(Sender: TObject);
var
  Info: string;
begin
  if FImage.Valid then
  begin
    Info := Format(
      'File: %s'#13#10 +
      'Dimensions: %d x %d'#13#10 +
      'Format: %s'#13#10 +
      'Size in memory: %s'#13#10 +
      'Load time: %.2f ms'#13#10 +
      'Convert time: %.2f ms',
      [ExtractFileName(FFileName),
       FImage.Width, FImage.Height,
       GetFormatName(FImage.Format),
       FormatByteSize(FImage.Size),
       FLoadTimeMs, FConvertTimeMs]);
    MessageDlg('Image Information', Info, mtInformation, [mbOK], 0);
  end
  else
    MessageDlg('No Image', 'No image loaded.', mtInformation, [mbOK], 0);
end;

procedure TFormMain.MenuAboutClick(Sender: TObject);
begin
  MessageDlg('About',
    'BGRA Image Viewer'#13#10 +
    'Using Vampyre Imaging Library ' + Imaging.GetVersionStr + #13#10 +
    #13#10 +
    'Demonstrates using Dracoola Imaging for loading'#13#10 +
    'and BGRABitmap for high-performance display.'#13#10 +
    #13#10 +
    'Supports: PNG, JPEG, BMP, TGA, DDS, GIF, MNG, JNG,'#13#10 +
    'TIFF, PSD, PCX, XPM, PBM/PGM/PPM/PAM, HDR/PFM, QOI, JP2',
    mtInformation, [mbOK], 0);
end;

procedure TFormMain.PaintBoxPaint(Sender: TObject);
var
  DestRect: TRect;
  Scale: Double;
  DestW, DestH: Integer;
begin
  // Clear background with checkerboard for transparency
  PaintBox.Canvas.Brush.Color := clBtnFace;
  PaintBox.Canvas.FillRect(PaintBox.ClientRect);

  if (FBGRABitmap.Width <= 1) or (FBGRABitmap.Height <= 1) then
    Exit;

  if FFitToWindow then
  begin
    // Calculate scaled size maintaining aspect ratio
    Scale := Math.Min(PaintBox.Width / FBGRABitmap.Width,
                      PaintBox.Height / FBGRABitmap.Height);
    if Scale > 1 then Scale := 1; // Don't upscale

    DestW := Round(FBGRABitmap.Width * Scale);
    DestH := Round(FBGRABitmap.Height * Scale);

    // Center the image
    DestRect.Left := (PaintBox.Width - DestW) div 2;
    DestRect.Top := (PaintBox.Height - DestH) div 2;
    DestRect.Right := DestRect.Left + DestW;
    DestRect.Bottom := DestRect.Top + DestH;

    // Draw scaled using BGRABitmap's high-quality resampling
    FBGRABitmap.Draw(PaintBox.Canvas, DestRect, True);
  end
  else
  begin
    // Draw at actual size
    FBGRABitmap.Draw(PaintBox.Canvas, 0, 0, False);
  end;
end;

procedure TFormMain.ScrollBoxResize(Sender: TObject);
begin
  UpdateView;
end;

procedure TFormMain.LoadImage(const AFileName: string);
var
  T1, T2: Int64;
begin
  FFileName := AFileName;

  try
    // Load using Dracoola Imaging
    T1 := GetTimeMicroseconds;
    FImage.LoadFromFile(AFileName);
    T2 := GetTimeMicroseconds;
    FLoadTimeMs := (T2 - T1) / 1000.0;

    // Convert to BGRA for display
    T1 := GetTimeMicroseconds;
    ConvertToBGRA;
    T2 := GetTimeMicroseconds;
    FConvertTimeMs := (T2 - T1) / 1000.0;

    UpdateView;
    UpdateStatusBar;

    Caption := Format('BGRA Image Viewer - %s', [ExtractFileName(AFileName)]);
    LabelInfo.Caption := Format('%s - %dx%d %s',
      [ExtractFileName(AFileName), FImage.Width, FImage.Height,
       GetFormatName(FImage.Format)]);
  except
    on E: Exception do
    begin
      MessageDlg('Error', 'Failed to load image: ' + E.Message, mtError, [mbOK], 0);
      FImage.CreateFromParams(1, 1, ifA8R8G8B8);
      FBGRABitmap.SetSize(1, 1);
      UpdateView;
    end;
  end;
end;

procedure TFormMain.ConvertToBGRA;
var
  TempData: TImageData;
  X, Y: Integer;
  SrcPtr: PColor32Rec;
  DstPtr: PBGRAPixel;
begin
  if not FImage.Valid then Exit;

  // Initialize temp data for conversion
  InitImage(TempData);
  try
    // Clone and convert to A8R8G8B8 (32-bit ARGB)
    CloneImage(FImage.ImageDataPointer^, TempData);
    ConvertImage(TempData, ifA8R8G8B8);

    // Resize BGRA bitmap
    FBGRABitmap.SetSize(TempData.Width, TempData.Height);

    // Copy pixels - Dracoola uses ARGB order: B, G, R, A in memory (little-endian)
    // TBGRAPixel: blue, green, red, alpha - same memory layout
    SrcPtr := PColor32Rec(TempData.Bits);
    for Y := 0 to TempData.Height - 1 do
    begin
      DstPtr := FBGRABitmap.ScanLine[Y];
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

    FBGRABitmap.InvalidateBitmap;
  finally
    FreeImage(TempData);
  end;
end;

procedure TFormMain.UpdateView;
begin
  if FFitToWindow then
  begin
    // Fill the scroll box
    PaintBox.Align := alClient;
    ScrollBox.HorzScrollBar.Visible := False;
    ScrollBox.VertScrollBar.Visible := False;
  end
  else
  begin
    // Use actual image size
    PaintBox.Align := alNone;
    PaintBox.Width := FBGRABitmap.Width;
    PaintBox.Height := FBGRABitmap.Height;
    ScrollBox.HorzScrollBar.Visible := True;
    ScrollBox.VertScrollBar.Visible := True;
  end;
  PaintBox.Invalidate;
end;

procedure TFormMain.UpdateStatusBar;
begin
  StatusBar.SimpleText := Format('  Load: %.2f ms | Convert: %.2f ms | %s',
    [FLoadTimeMs, FConvertTimeMs, FormatByteSize(FImage.Size)]);
end;

function TFormMain.GetOpenFilter: string;
begin
  // Build filter for all supported formats
  Result := 'All Supported Images|*.png;*.jpg;*.jpeg;*.bmp;*.tga;*.dds;*.gif;' +
            '*.mng;*.jng;*.tif;*.tiff;*.psd;*.pcx;*.xpm;*.pbm;*.pgm;*.ppm;*.pam;' +
            '*.hdr;*.pfm;*.qoi;*.jp2;*.ico|' +
            'PNG Images (*.png)|*.png|' +
            'JPEG Images (*.jpg;*.jpeg)|*.jpg;*.jpeg|' +
            'Windows Bitmap (*.bmp)|*.bmp|' +
            'Targa Images (*.tga)|*.tga|' +
            'DirectDraw Surface (*.dds)|*.dds|' +
            'GIF Images (*.gif)|*.gif|' +
            'MNG Images (*.mng)|*.mng|' +
            'JNG Images (*.jng)|*.jng|' +
            'TIFF Images (*.tif;*.tiff)|*.tif;*.tiff|' +
            'Photoshop (*.psd)|*.psd|' +
            'PCX Images (*.pcx)|*.pcx|' +
            'XPM Images (*.xpm)|*.xpm|' +
            'Portable Maps (*.pbm;*.pgm;*.ppm;*.pam)|*.pbm;*.pgm;*.ppm;*.pam|' +
            'HDR/PFM Images (*.hdr;*.pfm)|*.hdr;*.pfm|' +
            'QOI Images (*.qoi)|*.qoi|' +
            'JPEG 2000 (*.jp2)|*.jp2|' +
            'Windows Icon (*.ico)|*.ico|' +
            'All Files (*.*)|*.*';
end;

end.
