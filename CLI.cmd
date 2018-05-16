@ECHO OFF

SET PWD=%~dp0

SET TMP=%PWD%Temp
SET TEMP=%PWD%Temp
SET PSScriptRoot=%PWD:~0,-1%
SET PSModulePath=%PSScriptRoot%\Modules;%PSModulePath%
SET PSDisableModuleAnalysisCacheCleanup=1
SET PSModuleAnalysisCachePath=%TEMP%\PSModuleAnalysisCache\%COMPUTERNAME%-%USERDOMAIN%-%USERNAME%.cache

%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoExit -WindowStyle Maximized -File "%PSScriptRoot%\CLI.ps1"

EXIT /b %ERRORLEVEL%
GOTO :eof