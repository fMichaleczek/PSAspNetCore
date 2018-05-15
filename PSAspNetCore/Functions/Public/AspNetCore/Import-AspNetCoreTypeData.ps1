function Import-AspNetCoreTypeData {
    [CmdletBinding()]
	param(
		[string]
		$TypeDataPath = "$PSModuleRoot\TypeData\Microsoft.AspNetCore.All",

		[switch]
		$Force
	)
	if ( -not ( Test-Path $TypeDataPath ) -or $Force ) {
		Write-Verbose "Import AspNetTypeData : $TypeDataPath not exist"
		Export-AspNetCoreTypeData @PSBoundParameters
	}
	if ( Test-Path $TypeDataPath ) {
		Get-ChildItem -Path $TypeDataPath -Filter '*.ps1xml' | Foreach-Object {
            Write-Verbose "Import TypeData : '$($_.FullName)'"
            Update-TypeData -PrependPath $_.FullName
        }
	}
	else {
		Write-Error 'Path not found : $TypeDataPath'
	}
}
