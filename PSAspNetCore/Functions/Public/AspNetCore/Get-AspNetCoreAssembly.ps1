function Get-AspNetCoreAssembly {
    [CmdletBinding()]
	param(
        [Alias('AssemblyPath')]
		[string]
		$Path = "$PSModuleRoot\Assemblies\Microsoft.AspNetCore.All",
		
        [string]
        $Version,
        
		[string]
		$IgnorePattern,

		[System.IO.FileInfo[]]
		$File
	)
    if ( -not $PSBoundParameters['Version'] ) {
        $VersionPath =  Get-ChildItem -Path $Path -Directory | Sort Name -Desc | Select -Index 0  | Select -Expand FullName
    }
    else {
        $VersionPath = Join-Path $Path $Version
    }
    
	$Files = Get-ChildItem -Path $VersionPath -Filter "*.dll"
    
	Write-Verbose "Analyzing $($Files.Count) dll file(s)"
	
	if ( -not $PSBoundParameters['IgnorePattern']) {
		$PSBoundParameters['IgnorePattern'] = $IgnorePattern = "^api-ms-win|^clr|^mscor|^sos|^coreclr|^dbgshim$|^e_sqlite3$|^hostfxr$|^hostpolicy$|^libuv|^mi$|^miutils$|^sni$|^ucrtbase$"
	}

	if ($PSBoundParameters['IgnorePattern']) {
		$Files = $Files | Where-Object { $_.BaseName -notmatch $IgnorePattern }
		Write-Verbose "Filtering $($Files.Count) dll file(s)"
	}
    
	$Files | Where-Object { [char]::IsUpper($_.BaseName,0) -and $_.BaseName -notlike "*.native.*" -and $_.BaseName -ne 'System.Private.CoreLib' }
}
