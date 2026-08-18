@echo off
setlocal

set "REPO_ROOT=%~dp0.."
set "DECODER=%REPO_ROOT%\_build\native\release\build\cmd\toml-test-decoder\toml-test-decoder.exe"

if not exist "%DECODER%" (
  pushd "%REPO_ROOT%" || exit /b 1
  call moon build --release --target native cmd/toml-test-decoder 1>&2
  if errorlevel 1 exit /b 1
  popd
)

"%DECODER%"
exit /b %ERRORLEVEL%
