function Import-AspNetCoreAssembly {
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
		$File,
		
		[switch]
		$PassThru
	)    
    if ( -not $PSBoundParameters['Version'] ) {
        $VersionPath =  Get-ChildItem -Path $Path -Directory | Sort Name -Desc | Select -Index 0  | Select -Expand FullName
    }
    else {
        $VersionPath = Join-Path $Path $Version
    }
    Push-Location -Path $VersionPath
	$PSBoundParameters.Remove('PassThru') | Out-Null
	Get-AspNetCoreAssembly @PSBoundParameters | Foreach-Object {
		$FilePath = $_.FullName
		try { 
			Add-Type -Path $FilePath -PassThru:$PassThru  
		}
		catch [BadImageFormatException] {
			Write-Warning "File '$FilePath' is not Dot Net assembly"
		}
		catch { 
			Write-Error "File '$FilePath' error : $($_.Exception.ToString()) "
		}
	}
    Pop-Location
}
