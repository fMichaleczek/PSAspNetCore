# Classes on which other classes might depend, must be specified in order
$AssemblyDependencies = @()
$ClassDependencies = @()

#----------------------------------------------------------------------------------------------------------
$ErrorActionPreference = "Stop"

$PSModuleRoot = $PSScriptRoot

$Bootstrap  = Get-ChildItem ( Join-Path $PSScriptRoot Bootstrap ) -ErrorAction SilentlyContinue -Filter *.ps1 -Recurse
# $Assemblies = Get-ChildItem ( Join-Path $PSScriptRoot Assemblies ) -ErrorAction SilentlyContinue -Filter *.dll -Recurse
$Interfaces = Get-ChildItem ( Join-Path $PSScriptRoot Interfaces ) -ErrorAction SilentlyContinue -Filter I*.ps1 -Recurse
$Classes    = Get-ChildItem ( Join-Path $PSScriptRoot Classes ) -ErrorAction SilentlyContinue -Filter *.ps1 -Recurse
$Private    = Get-ChildItem ( Join-Path $PSScriptRoot ( Join-Path Functions Private ) ) -ErrorAction SilentlyContinue -Filter *.ps1 -Recurse
$Public     = Get-ChildItem ( Join-Path $PSScriptRoot ( Join-Path Functions Public ) ) -ErrorAction SilentlyContinue -Filter *.ps1 -Recurse

#----------------------------------------------------------------------------------------------------------

<#
# dot source the assemblies dependees
foreach ( $AssemblyDependency in @( $AssemblyDependencies ) ) {
    Write-Verbose "Loading dependency assembly '$AssemblyDependency'"
    try {
        Add-Type -Path $AssemblyDependency.FullName > $null
    }
    catch{
        Write-Error -Message "Failed to import dependency assembly $($AssemblyDependency.FullName): $_"
    }
}

# dot source assemblies
foreach ( $Assembly in @( $Assemblies ) ) {
    Write-Verbose "Loading assembly '$Assembly'"
    try {
        # Add-Type -Path $Assembly.FullName > $null
    }
    catch{
        Write-Error -Message "Failed to import assembly $($Assembly.FullName): $_"
    }
}
#>


# dot source BootFunction functions
foreach ( $BootFunction in @( $Bootstrap ) ) {
    Write-Verbose "Loading public function '$BootFunction'"
    try {
        . $BootFunction.FullName
    }
    catch {
        Write-Error -Message "Failed to import bootstrap function $($BootFunction.FullName): $_"
    }
}

Import-AspNetCoreAssembly -WhiteListPattern '^System.Buffers' -IgnorePattern '^Microsoft.AspNetCore.Server.Kestrel.Transport.Sockets|^System|^Microsoft.AspNetCore.Mvc.Razor.Extensions|^Microsoft.CodeAnalysis'

Import-AspNetCoreTypeData -IgnorePattern '^Newtonsoft.Json|^System|^Microsoft.AspNetCore.Razor'

Import-AspNetCoreAccelerator -Namespace @(
	'System.Threading', 'System.Threading.Tasks', 'System.Collections.Generic',
	'System.Linq.Expressions',
	'Microsoft.AspNetCore', 'Microsoft.AspNetCore.Builder', 'Microsoft.AspNetCore.Hosting','Microsoft.AspNetCore.Hosting.Internal',  'Microsoft.AspNetCore.Http.Features',
	'Microsoft.AspNetCore.Http', 'Microsoft.AspNetCore.Routing', 'Microsoft.Extensions.ObjectPool'
	'Microsoft.Extensions.Configuration', 'Microsoft.Extensions.Logging','Microsoft.Extensions.DependencyInjection', 'Microsoft.Extensions.Primitives'
	'Microsoft.AspNetCore.Server.Kestrel.Core', 'Microsoft.AspNetCore.Hosting.Server', 'System.Reflection', 'Microsoft.Extensions.Options',
	'Microsoft.AspNetCore.Hosting.Builder', 'System.Diagnostics',
	'Microsoft.AspNetCore.Mvc', 'Microsoft.AspNetCore.Mvc.Formatters', 'Microsoft.AspNetCore.Mvc.Internal',
	'Microsoft.AspNetCore.Mvc.Routing', 'Microsoft.AspNetCore.Mvc.Controllers'
)

# dot source interfaces
foreach ( $Interface in @( $Interfaces ) ) {
    Write-Verbose "Loading interface '$Interface'"
    try {
        . $Interface.FullName
    }
    catch {
        Write-Error -Message "Failed to import interface $($Interface.FullName): $_"
    }
}

# dot source the class dependees
foreach( $ClassDependency in @( $ClassDependencies ) ) {
    Write-Verbose "Loading dependency class '$ClassDependency'"
    try{
        . ( Join-Path ( Join-Path $PSScriptRoot Classes ) "$ClassDependency.ps1" )
    }
    catch{
        Write-Error -Message "Failed to import dependency class $($ClassDependency): $_"
    }
}

# dot source classes
foreach ( $Class in @( $Classes ) ) {
    Write-Verbose "Loading Class '$Class'"
    try {
        . $Class.FullName
    }
    catch {
        Write-Error -Message "Failed to import Class $($Class.FullName): $_"
    }
}

# dot source private functions
foreach( $PriFunction in @( $Private ) ) {
    Write-Verbose "Loading private function '$PriFunction'"
    try{
        . $PriFunction.FullName
    }
    catch{
        Write-Error -Message "Failed to import private function $($PriFunction.FullName): $_"
    }
}


# dot source public functions
foreach ( $PubFunction in @( $Public ) ) {
    Write-Verbose "Loading public function '$PubFunction'"
    try {
        . $PubFunction.FullName
    }
    catch {
        Write-Error -Message "Failed to import public function $($PubFunction.FullName): $_"
    }
}

#----------------------------------------------------------------------------------------------------------

# Export public functions
Write-Verbose "Exporting public functions: $($Public.BaseName)"
Export-ModuleMember -Function ( $Bootstrap.BaseName + $Public.BaseName )