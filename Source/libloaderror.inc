{ libloaderror.inc - shared "why did LoadLibrary fail" helper.

  Every native codec here (TurboJPEG, libjpeg, zlib-ng) is loaded lazily, and a
  miss only disables that codec. That keeps the library robust, but it also
  makes a failure invisible: to the user a photo that will not open looks like a
  corrupt file, not like a missing runtime. Each binding records the outcome in
  its own Last*LoadError string using the function below, so the host
  application can name the file and the reason.

  Include inside the implementation section of a binding unit:

      {$I ../libloaderror.inc}

  Requires SysUtils in scope, and the Windows unit on Windows (for GetLastError).
  Declared local to each including unit on purpose - these bindings are meant to
  stay individually self-contained. }

function DescribeLibLoadFailure(const ALib: string): string;
var
  Existed: Boolean;
  OSText: string;
{$IFDEF MSWINDOWS}
  Code: Integer;
{$ENDIF}
begin
  if (Pos('/', ALib) > 0) or (Pos('\', ALib) > 0) then
    Existed := FileExists(ALib)
  else
    Existed := FileExists(ExtractFilePath(ParamStr(0)) + ALib);
{$IFDEF MSWINDOWS}
  Code := Integer(GetLastError);
  OSText := Trim(SysErrorMessage(Code));
  if (Code = 126) and Existed then
    { ERROR_MOD_NOT_FOUND with the file present means a *dependency* is missing,
      which is a completely different fix from "the file is missing". }
    Result := '"' + ALib + '" is present but could not be loaded, because a ' +
      'library it depends on is missing - most often the Microsoft Visual C++ ' +
      '2015-2022 Redistributable (x64).'
  else if Code = 193 then
    Result := '"' + ALib + '" is the wrong architecture for this program ' +
      '(a 32-bit library cannot load into a 64-bit process).'
  else if Existed then
    Result := '"' + ALib + '" is present but could not be loaded.'
  else
    Result := '"' + ALib + '" was not found next to the program or on the ' +
      'system search path.';
{$ELSE}
  OSText := '';
  if Existed then
    Result := '"' + ALib + '" is present but could not be loaded; a library ' +
      'it depends on is probably missing or of the wrong architecture.'
  else
    Result := '"' + ALib + '" was not found next to the program or on the ' +
      'library search path.';
{$ENDIF}
  if OSText <> '' then
    Result := Result + ' The system reports: ' + OSText + '.';
end;
