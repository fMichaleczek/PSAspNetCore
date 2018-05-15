Install-Module UncommonSense.PowerShell.TypeData, GenericMethods, PSRunspacedDelegate, PSLambda

$PSGalleryPublishUri = 'https://www.myget.org/F/ottomatt/api/v2/package'
$PSGallerySourceUri = 'https://www.myget.org/F/ottomatt/api/v2'
Register-PSRepository -Name OttoMatt -SourceLocation $PSGallerySourceUri -PublishLocation $PSGalleryPublishUri #-InstallationPolicy Trusted
Install-Module ExtensionMethod -Repository OttoMatt

