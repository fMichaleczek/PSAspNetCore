function Get-AspNetCoreExtensionMethodType {
    [CmdletBinding()]
	param(
		[type[]]
		$Type,
		
		[string]
		$Path = "$PSModuleRoot\Assemblies\Microsoft.AspNetCore.All",
		
		[string]
		$Version
	)
    
    if ( -not $PSBoundParameters['Version'] ) {
        $VersionPath =  Get-ChildItem -Path $Path -Directory | Sort Name -Desc | Select -Index 0  | Select -Expand FullName
    }
    else {
        $VersionPath = Join-Path $Path $Version
    }

    if ( -not $PSBoundParameters.ContainsKey('Type') ) {
        $Type = Get-AspNetCoreType -Path $VersionPath -FilterTypeName '^Microsoft.AspNetCore.Mvc.ViewFeatures|^Microsoft.AspNetCore.Http.Abstractions|^Microsoft.Extensions.DependencyInjection.Abstractions'
        Write-Verbose "Get $($Type.Count) type(s)"
    }
    
    if ( $null -ne $Type ) {
        $ExtensionTypes = @()
        foreach ($EachType in @( $Type | Sort-Object FullName ) ) {
            $ExtensionMethods = @( Get-AspNetCoreExtensionMethod -Type $EachType )
            foreach ( $ExtensionMethod in $ExtensionMethods ) {
               $ExtensionTypes += [PSCustomObject]@{
                    ExtensionType = $EachType
                    Type = $ExtensionMethod.Name
                    Methods = @($ExtensionMethod.Value)
                }
            }
        }
        
        $GroupedExtensionTypes = $ExtensionTypes | Group Type
        
        $TypeData = @()
        foreach ( $GroupedExtensionType in $GroupedExtensionTypes ) {
            $Value = $GroupedExtensionType.Group.Methods | Group Name | 
                        Foreach { 
                            $Group = $_.Group 
                            $Group | Add-Member -MemberType NoteProperty -Name ParametersCount -Value $Group.GetParameters().Count -Force
                            $Group | Group ParametersCount | 
                            Foreach { 
                                $_.Group | Select -First 1 
                            }
                        }

            $DictionaryEntry = [System.Collections.DictionaryEntry]::new($GroupedExtensionType.Name, $Value)
            $ExtensionMethodTypes =  New-ExtensionMethodType $DictionaryEntry
            $TypeData += New-TypeData -PreContent '<?xml version="1.0" encoding="utf-8" ?>' -Types { $ExtensionMethodTypes }
        }
    }
    
}
