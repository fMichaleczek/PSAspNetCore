$PSModulePath = "$PSScriptRoot\Modules"

if ( -not ( Test-Path $PSModulePath ) ) {

    New-Item -Path $PSModulePath -ItemType Directory > $null

    $OttoMattPSRepository = @{
        Name = 'OttoMatt'
        PublishLocation = 'https://www.myget.org/F/ottomatt/api/v2/package'
        SourceLocation = 'https://www.myget.org/F/ottomatt/api/v2'   
      # InstallationPolicy = 'Trusted'
    }
    Register-PSRepository @OttoMattPSRepository

    Save-Module UncommonSense.PowerShell.TypeData  -Repository PSGallery -Path $PSModulePath
    Save-Module GenericMethods  -Repository PSGallery -Path $PSModulePath
    Save-Module PSLambda  -Repository PSGallery -Path $PSModulePath
    Save-Module ExtensionMethod -Repository OttoMatt -Path $PSModulePath
}
