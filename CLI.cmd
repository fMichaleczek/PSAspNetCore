@ECHO OFF

%SystemRoot%\system32\attrib.exe %SystemRoot%\system32 -h | findstr.exe /I "system32" >nul
IF %ERRORLEVEL% neq 1 (
    %SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -ExecutionPolicy ByPass -WindowStyle Hidden -Command "Start-Process '%0' -Verb RunAs"
	EXIT /b %ERRORLEVEL%
	GOTO :eof	
)

SET PWD=%~dp0

SET TMP=%PWD%Temp
SET TEMP=%PWD%Temp
SET PSScriptRoot=%PWD:~0,-1%
SET PSModulePath=%PSScriptRoot%\Modules;%PSModulePath%
SET PSDisableModuleAnalysisCacheCleanup=1
SET PSModuleAnalysisCachePath=%TEMP%\PSModuleAnalysisCache\%COMPUTERNAME%-%USERDOMAIN%-%USERNAME%.cache

%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -NoExit -WindowStyle Maximized -Command "Set-Location '%PSScriptRoot%' ; Write-Host -Foreground White -Background DarkRed 'PSAspNetCore CLI' ;"

EXIT /b %ERRORLEVEL%
GOTO :eof