@ECHO OFF

attrib.exe %WINDIR%\system32 -h | findstr.exe /I "system32" >nul
IF %ERRORLEVEL% neq 1 (
    powershell.exe -nol -nop -ex ByPass -WindowStyle Hidden -c "Start-Process '%0' -v RunAs"
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

%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -NoExit -WindowStyle Maximized -Command "Set-Location '%PSScriptRoot%' ; Write-Host -Fore White -back DarkRed 'CLI' ;"

EXIT /b %ERRORLEVEL%
GOTO :eof