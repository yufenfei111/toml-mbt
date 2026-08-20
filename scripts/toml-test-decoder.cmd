@echo off
setlocal
set "DECODER=%~dp0..\_build\native\release\build\cmd\toml-test-decoder\toml-test-decoder.exe"
if "%TOML_TEST_DECODER_NO_BUILD%"=="1" goto run_decoder
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0toml-test-build.ps1" -RepoRoot "%~dp0.."
exit /b %ERRORLEVEL%

:run_decoder
if not exist "%DECODER%" (
  echo prebuilt decoder is missing: %DECODER% 1>&2
  exit /b 1
)
"%DECODER%"
exit /b %ERRORLEVEL%
