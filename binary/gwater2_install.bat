@echo off
SETLOCAL EnableDelayedExpansion
title GWater2 Installer

FOR /F "tokens=*" %%a in ('powershell -command $PSVersionTable.PSVersion.Major 2^>nul') do set powershell_version=%%a
if defined powershell_version if !powershell_version! geq 4 GOTO prompt
echo This script requires Windows PowerShell 4.0+ (included in Windows 8.1 and later)
pause & exit

:prompt
cls
FOR /F "tokens=2* skip=2" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Valve\Steam" /v "InstallPath" 2^>nul') do set steam_dir=%%b
FOR /F "tokens=2* skip=2" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam" /v "InstallPath" 2^>nul') do set steam_dir=%%b
if not defined steam_dir (
	echo "Steam installation path not found. Please get gwater2 manually by downloading the .zip"
	pause
	exit
)
if exist "%steam_dir%\steamapps\appmanifest_4000.acf" set "gmod_dir=%steam_dir%\steamapps\common\GarrysMod"
for /f "usebackq tokens=2 skip=4" %%A in ("%steam_dir%\steamapps\libraryfolders.vdf") do (
  if exist "%%~A\steamapps\appmanifest_4000.acf" set "gmod_dir=%%~A\steamapps\common\GarrysMod"
)
if not defined gmod_dir (
	echo "GMod installation path not found. Please get gwater2 manually by downloading the .zip"
	pause
	exit
)

echo Detected Directory: %gmod_dir%
echo Make sure to close GMod before running the installer.
echo.

echo Select an option (Type 1 or 2 and hit enter):
echo 1) install
echo 2) uninstall
set /p choice="> "

cls
if %choice%==1 GOTO install
if %choice%==2 GOTO uninstall
echo Invalid option. Valid options are: 1, 2
pause
goto prompt

:install
pushd %gmod_dir%
echo Downloading gwater2...
powershell -command [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest 'https://github.com/meetric1/gwater2/releases/download/v1.0/gwater2_1.0.zip' -Out gwater2.zip

if not exist gwater2.zip (
	echo Download failed, Invalid Link
	pause
	exit
)

echo Decompressing...
powershell -command Expand-Archive gwater2.zip -Force
echo Installing...
rmdir ".\garrysmod\addons\gwater2" /s /q
xcopy /e /y /q gwater2 .
rmdir /s /q gwater2
del gwater2.zip
echo.
echo Finished Install
echo.
pause
exit

:uninstall
pushd %gmod_dir%
echo Uninstalling...
del ".\garrysmod\lua\bin\gmcl_gwater2_win32.dll"
del ".\garrysmod\lua\bin\gmcl_gwater2_win64.dll"
del ".\garrysmod\lua\bin\gmcl_gwater2_main_win32.dll"
rmdir ".\garrysmod\addons\gwater2" /s /q
del ".\garrysmod\shaders\fxc\GWaterFinalpass_ps30.vcs"
del ".\garrysmod\shaders\fxc\GWaterFinalpass_vs30.vcs"
del ".\garrysmod\shaders\fxc\GWaterNormals_ps30.vcs"
del ".\garrysmod\shaders\fxc\GWaterNormals_vs30.vcs"
del ".\garrysmod\shaders\fxc\GWaterSmooth_ps30.vcs"
del ".\garrysmod\shaders\fxc\GWaterVolumetric_ps30.vcs"
del ".\garrysmod\shaders\fxc\GWaterVolumetric_vs30.vcs"
del ".\amd_ags_x64.dll"
del ".\amd_ags_x86.dll"
del ".\GFSDK_Aftermath_Lib.x64.dll"
del ".\GFSDK_Aftermath_Lib.x86.dll"
del ".\NvFlexExtReleaseD3D_x64.dll"
del ".\NvFlexExtReleaseD3D_x86.dll"
del ".\NvFlexReleaseD3D_x64.dll"
del ".\NvFlexReleaseD3D_x86.dll"
del ".\nvToolsExt32_1.dll"
del ".\nvToolsExt64_1.dll"

echo Finished Uninstall
pause
