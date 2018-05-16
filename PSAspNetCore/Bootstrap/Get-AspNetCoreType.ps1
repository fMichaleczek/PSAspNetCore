function Get-AspNetCoreType {
    [CmdletBinding()]
    [OutputType([Type[]])]
	param(
        [Alias('AssemblyPath')]
		[string]
		$Path = "$PSModuleRoot\Assemblies\Microsoft.AspNetCore.All",
		
		[System.IO.FileInfo[]]
		$File,
		
		[string]
		$FilterTypeName,
		
		[string[]]
		$FilterNamespace
	)
	begin {
		if ($PSBoundParameters['File'] ) {
			$Assemblies = [appdomain]::CurrentDomain.GetAssemblies() | Where Location -in $File.FullName
		}
		else {
			$Assemblies = [appdomain]::CurrentDomain.GetAssemblies() | Where Location -like "$Path*"
		}
	}
	process {
    
		$Types = $Assemblies.Where{ -not $_.IsDynamic -and $_.GetName().Name -notlike 'Microsoft.CodeAnalysis*' }.Foreach{ try { $_.GetExportedTypes() } catch { } }
		Write-Verbose "Finding $($Types.Count) type(s)"
		
		$FilteredTypes = @( $Types | Where-Object { $_ -ne $null -and $_.IsPublic -and $_.IsGenericType -eq $false -and $_.IsNested -eq $false } )
		
		if ( $PSBoundParameters['FilterTypeName'] ) {
			$FilteredTypes = @( $FilteredTypes | Where-Object { $_.FullName -notlike $FilterTypeName } )
			Write-Verbose "Filtering TypeName $($FilteredTypes.Count) type(s)"
		}
		
		if ( $PSBoundParameters['FilterNamespace'] ) {
			$FilteredTypes = @( $FilteredTypes | Where-Object { $_.Namespace.ToString() -notlike $FilterNamespace } )
			Write-Verbose "Filtering Namespace $($FilteredTypes.Count) type(s)"	
		}
		
		Write-Verbose "Return $($FilteredTypes.Count) type(s)"
		[type[]]@($FilteredTypes)
	}	
}
