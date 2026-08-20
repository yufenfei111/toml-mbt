@echo off
setlocal
set "REPO_ROOT=%~dp0.."
set "DECODER=%REPO_ROOT%\_build\native\release\build\cmd\toml-test-decoder\toml-test-decoder.exe"

if exist "%DECODER%" (
  "%DECODER%" <nul >nul 2>nul
  if not errorlevel 1 goto run_decoder
)

:allocate_build_log
set "BUILD_LOG_DIR=%TEMP%\toml-test-decoder-build-%RANDOM%-%RANDOM%"
mkdir "%BUILD_LOG_DIR%" 2>nul
if errorlevel 1 goto allocate_build_log
set "BUILD_LOG=%BUILD_LOG_DIR%\build.log"

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0toml-test-build.ps1" -RepoRoot "%REPO_ROOT%" <nul >"%BUILD_LOG%" 2>&1
set "BUILD_STATUS=%ERRORLEVEL%"
if not "%BUILD_STATUS%"=="0" (
  type "%BUILD_LOG%" 1>&2
  del /q "%BUILD_LOG%" >nul 2>&1
  rmdir "%BUILD_LOG_DIR%" >nul 2>&1
  exit /b %BUILD_STATUS%
)
del /q "%BUILD_LOG%" >nul 2>&1
rmdir "%BUILD_LOG_DIR%" >nul 2>&1

:run_decoder
"%DECODER%"
exit /b %ERRORLEVEL%
