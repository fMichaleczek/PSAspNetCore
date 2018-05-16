function Import-AspNetCoreTypeData {
    [CmdletBinding()]
	param(
		[string]
		$TypeDataPath = "$PSModuleRoot\TypeData\Microsoft.AspNetCore.All",
        
		[string]
		$IgnorePattern,

		[switch]
		$Force
	)
	if ( -not ( Test-Path $TypeDataPath ) -or $Force ) {
		Write-Verbose "Import AspNetTypeData : $TypeDataPath not exist"
		Export-AspNetCoreTypeData @PSBoundParameters
	}
	if ( Test-Path $TypeDataPath ) {
    
        $Files = Get-ChildItem -Path $TypeDataPath -Filter '*.ps1xml'
    
        if ($PSBoundParameters['IgnorePattern']) {
            $Files = $Files | Where-Object { $_.BaseName -notmatch $IgnorePattern }
            Write-Verbose "Filtering $($Files.Count) ps1xml file(s)"
        }
    
		$Files | Foreach-Object {
            Write-Verbose "Import TypeData : '$($_.FullName)'"
            Update-TypeData -PrependPath $_.FullName
        }
	}
	else {
		Write-Error 'Path not found : $TypeDataPath'
	}
}
