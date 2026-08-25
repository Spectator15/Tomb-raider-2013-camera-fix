@echo off
rem GENERATED FILE: contributors should edit the source files in src.
rem Rebuild the ready-to-run batch with build\Build-Release.ps1.
setlocal DisableDelayedExpansion
chcp 65001 >nul
set "TRCF_SELF=%~f0"
set "TRCF_ARG_COUNT=0"
set "TRCF_HAD_ARGS=0"
set "TRCF_WAIT_ON_ERROR=0"

:trcf_collect_args
if "%~1"=="" goto trcf_launch
set "TRCF_HAD_ARGS=1"
set /a TRCF_ARG_COUNT+=1 >nul
set "TRCF_ARG_%TRCF_ARG_COUNT%=%~1"
shift
goto trcf_collect_args

:trcf_launch
if "%TRCF_ELEVATED_LAUNCH%"=="1" set "TRCF_HAD_ARGS=1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:TRCF_SELF;$m='#'+'__TOMB_RAIDER_CAMERA_FIX_POWERSHELL__';$t=[IO.File]::ReadAllText($p);$i=$t.IndexOf($m,[StringComparison]::Ordinal);if($i -lt 0){throw 'The embedded PowerShell marker is missing.'};$c=$t.Substring($i+$m.Length);$h=@{StandaloneBatchPath=$p};if($env:TRCF_ELEVATED_LAUNCH -eq '1'){$h.ExePath=$env:TRCF_ELEVATED_EXE;$h.Action=$env:TRCF_ELEVATED_ACTION;$h.PauseAfterAction=$true;if($h.Action -eq 'Apply'){$h.ApplyConfirmed=$true};if($env:TRCF_ELEVATED_FAILURE){$h.TestFailurePoint=$env:TRCF_ELEVATED_FAILURE}}else{$n=[int]$env:TRCF_ARG_COUNT;for($j=1;$j -le $n;$j++){$v=[Environment]::GetEnvironmentVariable(('TRCF_ARG_'+$j),'Process');if($v -ieq '-Action'){if($j -ge $n){throw '-Action requires a value.'};$j++;$h.Action=[Environment]::GetEnvironmentVariable(('TRCF_ARG_'+$j),'Process');continue};if($v -ieq '-ApplyConfirmed'){$h.ApplyConfirmed=$true;continue};if($v -ieq '-PauseAfterAction'){$h.PauseAfterAction=$true;continue};if($v -ieq '-TestFailurePoint'){if($j -ge $n){throw '-TestFailurePoint requires a value.'};$j++;$h.TestFailurePoint=[Environment]::GetEnvironmentVariable(('TRCF_ARG_'+$j),'Process');continue};if($h.ContainsKey('ExePath')){throw ('Unknown extra argument: '+$v)};$h.ExePath=$v}};& ([ScriptBlock]::Create($c)) @h"
set "TRCF_EXIT=%ERRORLEVEL%"
if "%TRCF_EXIT%"=="0" goto trcf_return
echo.
echo Tomb Raider Complete Camera Fix stopped with an error. Exit code: %TRCF_EXIT%
if "%TRCF_HAD_ARGS%"=="0" set "TRCF_WAIT_ON_ERROR=1"
if "%TRCF_FORCE_WAIT_ON_ERROR%"=="1" set "TRCF_WAIT_ON_ERROR=1"
if not "%TRCF_WAIT_ON_ERROR%"=="1" goto trcf_return
echo Press any key to close this window...
pause >nul

:trcf_return
endlocal & exit /b %TRCF_EXIT%

#__TOMB_RAIDER_CAMERA_FIX_POWERSHELL__
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ExePath,

    [ValidateSet('Menu', 'Status', 'Apply', 'Restore')]
    [string]$Action = 'Menu',

    [switch]$ApplyConfirmed,

    [switch]$PauseAfterAction,

    [switch]$LibraryMode,

    # Set only by the self-reading hybrid BAT. Kept as a normal string so the
    # embedded source stays transparent and testable.
    [string]$StandaloneBatchPath,

    # Safe failure injection used by the disposable-fixture test suites.
    [ValidateSet('None', 'AfterBackup', 'AfterTempWrite', 'BeforeReplace', 'AfterReplace')]
    [string]$TestFailurePoint = 'None',

    [switch]$ElevatedFromEnvironment
)
