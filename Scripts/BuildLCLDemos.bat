@echo OFF
rem LCL demos require Lazarus IDE with lazbuild.
rem Some demos require additional packages:
rem   - BGRAViewer requires BGRABitmapPack (install via Online Package Manager)
echo Building LCL Demos using lazbuild (Lazarus)
echo.

set ROOTDIR=..
set DEMOPATH=%ROOTDIR%\Demos\ObjectPascal

rem Find lazbuild - check common locations
set LAZBUILD=
if exist "C:\lazarus\lazbuild.exe" set LAZBUILD=C:\lazarus\lazbuild.exe
if exist "C:\Program Files\Lazarus\lazbuild.exe" set LAZBUILD=C:\Program Files\Lazarus\lazbuild.exe
if exist "C:\Program Files (x86)\Lazarus\lazbuild.exe" set LAZBUILD=C:\Program Files (x86)\Lazarus\lazbuild.exe

if "%LAZBUILD%"=="" (
    echo ERROR: lazbuild not found. Please install Lazarus IDE.
    echo Download from: https://www.lazarus-ide.org/
    exit /b 1
)

echo Using lazbuild: %LAZBUILD%
echo.

set DEMOSBUILD=0
set DEMOCOUNT=3

call :BUILD LCLImager\lclimager.lpi "LCL Imager"
call :BUILD ImageBrowser\ImgBrowser.lpi "Image Browser"
call :BUILD BGRAViewer\BGRAViewer.lpi "BGRA Viewer"

goto END

:BUILD
  echo Building %~2...
  "%LAZBUILD%" "%DEMOPATH%\%~1" >nul 2>&1
  if errorlevel 1 (
    echo   [FAILED] %~2 - trying with verbose output:
    "%LAZBUILD%" "%DEMOPATH%\%~1"
    echo.
  ) else (
    echo   [OK] %~2
    set /a DEMOSBUILD+=1
  )
goto :EOF

:END
echo.
if "%DEMOSBUILD%"=="%DEMOCOUNT%" (
  echo [92mBuild Successful - all %DEMOSBUILD% of %DEMOCOUNT% LCL demos built in Demos/Bin directory[0m
) else (
  echo [91mErrors during building - only %DEMOSBUILD% of %DEMOCOUNT% LCL demos built[0m
  echo.
  echo Note: BGRAViewer requires BGRABitmapPack package.
  echo Install it via: Tools ^> Online Package Manager ^> BGRABitmap
  exit /b 1
)
