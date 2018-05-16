function Import-AspNetCoreAccelerator {
    [CmdletBinding()]
	param(
		[string[]]
		$Namespace,
		
		[type[]]
		$Type
		
	)
	begin {
		$AcceleratorsType = [PSObject].Assembly.GetType("System.Management.Automation.TypeAccelerators")
		if ( $PSBoundParameters['Namespace'] ) {
			$Type = Get-AspNetCoreType -FilterNamespace $Namespace | Where-Object { -not $_.IsDefined([System.Runtime.CompilerServices.ExtensionAttribute], $false) } 
		}
	}
	process {
		$Type | Foreach-Object {
			Write-Debug "Add Accelerator $($_.FullName) => $($_.Name)"
			$AcceleratorsType::Add($_.Name, $_)
		}
	}
} 
