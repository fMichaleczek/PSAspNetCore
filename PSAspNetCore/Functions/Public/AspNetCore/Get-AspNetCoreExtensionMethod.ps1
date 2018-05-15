function Get-AspNetCoreExtensionMethod {
    [CmdletBinding()]
    [OutputType([System.Collections.DictionaryEntry[]])]
	param(
		[Parameter(Mandatory=$true, Position=0)]
		[Type[]]
		$Type,
		
		[switch]
		$ExcludeGenericType,
		
		[switch]
		$ExcludeGenericMethod,
		
		[switch]
		$ExcludeInterface
	)
	
	$ExtensionMethodTypes = @($Type) | Find-ExtensionMethod -ExcludeGeneric:$ExcludeGenericType
	Write-Verbose "Finding $($ExtensionMethodTypes.Count) type(s) with extension"
	
	$ExtensionMethods = $ExtensionMethodTypes | Foreach-Object {
		$_ | Get-ExtensionMethodInfo -ExcludeGeneric:$ExcludeGenericMethod -ExcludeInterface:$ExcludeInterface -ErrorAction SilentlyContinue 
    } | New-HashTable -key "Key" -Value "Value" -MakeArray
    
	Write-Verbose "Finding $($ExtensionMethods.Count) methods"
	
	$DomainTypes = @( [AppDomain]::CurrentDomain.GetAssemblies().Where{ -not $_.IsDynamic }.ExportedTypes )
	Write-Verbose "Comparing with $($DomainTypes.Count) domain type(s)"
	
	$Output = @()
	foreach ($ExtensionMethod in $ExtensionMethods.GetEnumerator() ) { 
        Write-Verbose "Searching Method $($ExtensionMethod.Name)"
        $Type = $ExtensionMethod.Name -as [type]
        if ( $Type.IsInterface ) {
            foreach ($DomainType in $DomainTypes) {
                if ( $DomainType.IsClass -and ( -not $DomainType.IsGenericType )-and ( $Type.FullName -in $DomainType.ImplementedInterfaces.FullName ) ) {
                    $Existant = $Output.Where{$_.Name -eq $DomainType.FullName} | Select -First 1
                    if ( $null -eq $Existant ) {
                        $Output += [System.Collections.DictionaryEntry]::new($DomainType.FullName, @($ExtensionMethod.Value))
                    }
                    else {
                        $Existant.Value += $ExtensionMethod.Value
                    }
                }
            }
        }
        elseif ( $Type.IsClass -and -not $Type.IsGenericType ) {
            $Existant = $Output.Where{$_.Name -eq $Type.FullName} | Select -First 1
            if ( $null -eq $Existant ) {
                $Output += [System.Collections.DictionaryEntry]::new($ExtensionMethod.Name, @($ExtensionMethod.Value))
            }
            else {
                $Existant.Value += $ExtensionMethod.Value
            }
        }
	}
	
	$Output
}
