Param($HttpContext)
Start-Transcript C:\test.log
Import-Module Microsoft.Powershell.Utility, Microsoft.PowerShell.Management -Global -WarningAction SilentlyContinue

function Write-Response {
	Param([Parameter(ValueFromPipeline=$True)][string[]]$message)
	Process { 
		foreach($msg in $message) { 
            [Microsoft.AspNetCore.Http.HttpResponseWritingExtensions]::WriteAsync($HttpContext.Response, $msg, [System.Threading.CancellationToken]::None)
        }
    }
}

function Write-ErrorResponse {
	Param([Parameter(ValueFromPipeline=$True)]$Err)
	Process { 
		$Html = $Err | ConvertTo-Html -Fragment -As List
		$Html += $Err.Exception | ConvertTo-Html -Fragment -As List
		$Html += $Err.Exception.InnerException | ConvertTo-Html -Fragment -As List
		$Html | Write-Response
	}
}

Write-Error "this is a error test"

try {
    $HttpContext.Response.ContentType = "text/html"
    $HttpContext.Response.StatusCode = [System.Net.HttpStatusCode]::OK

    $Request = $HttpContext.Request
	$Response = $HttpContext.Response
	
@"
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
	
	 <!-- Bootstrap -->
	<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css" integrity="sha384-1q8mTJOASx8j1Au+a5WDVnPi2lkFfwwEAa8hDDdjZlpLegxhjVME1fgjWPGmkzs7" crossorigin="anonymous">

	<!-- Bootstrap Optional theme -->
	<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap-theme.min.css" integrity="sha384-fLW2N01lMqjakBkx3l/M9EahuwpSfeNvV63J5ezn3uZzapT0u7EYsXMjQV+0En5r" crossorigin="anonymous">

	<!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->
    <!-- WARNING: Respond.js doesn't work if you view the page via file:// -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->
	

	<style type="text/css">
		h2 { color : #FF0000 ; padding-top : 10px ; }
		h3 { color : blue ; padding-top : 5px ; }
		table { border : 1px solid #CCCCCC !important}
		table th { background : FFCCCC ; border : 1px solid #CCCCCC !important ; padding : 5px ; font-size : 9px ; }
		table td { border : 1px solid #CCCCCC !important ; padding : 5px ; font-size : 12px ; }
		h3 { color : #FF0000 ; }
	</style>
	
</head>

<body>

"@ | Write-Response
	"<h1>DEBUG</h1>" | Write-Response
	
	"<h2>Variables</h2>" | Write-Response
    Get-Variable | ConvertTo-Html -Fragment | Write-Response
	
    "<h2>Context</h2>" | Write-Response
    $HttpContext  | Select * | ConvertTo-Html -Fragment -As List  | Write-Response
    
    "<h2>Context.Request</h2>" | Write-Response
    $Request  | Select * | ConvertTo-Html -Fragment -As List  | Write-Response
	"<h2>Context.Request Members</h2>" | Write-Response
    $Request  | Select * -First 1 | Get-Member | Where Name -notin @('Equals','GetHashCode','GetType','ToString') | Select Name,Definition,MemberType <#,TypeName #> | ConvertTo-Html -Fragment -As Table | Write-Response
    
	"<h3>Context.Request.Path</h3>" | Write-Response
	$Request.Path | ConvertTo-Html -Fragment | Write-Response
	"<h3>Context.Request.Query</h3>" | Write-Response
	$Request.Query | ConvertTo-Html  -Fragment| Write-Response
	"<h3>Context.Request.Headers</h3>" | Write-Response
	$Request.Headers | Select * | ConvertTo-Html -Fragment | Write-Response
	
    "<h2>Context.Response</h2>" | Write-Response
    $Response  | Select * | ConvertTo-Html -Fragment -As List  | Write-Response
	"<h2>Context.Response Members</h2>" | Write-Response
    $Response  | Select * -First 1 | Get-Member | Where Name -notin @('Equals','GetHashCode','GetType','ToString') | Select Name,Definition,MemberType <#,TypeName #> | ConvertTo-Html -Fragment -As Table | Write-Response
    
	"<h2>Context.User</h2>" | Write-Response
    $HttpContext.User  | Select * | ConvertTo-Html -Fragment -As List  | Write-Response
  
    "<h2>Context.Items</h2>" | Write-Response
    $HttpContext.Items  | Select * | ConvertTo-Html -Fragment -As List  | Write-Response
    
    
    "<h2>Context.ApplicationServices</h2>" | Write-Response
    $HttpContext.ApplicationServices  | Select * | ConvertTo-Html -Fragment -As List  | Write-Response
    "<h2>Context.ApplicationServices Members</h2>" | Write-Response
	$HttpContext.ApplicationServices  | Select * -First 1 | Get-Member | Where Name -notin @('Equals','GetHashCode','GetType','ToString') | Select Name,Definition,MemberType <#,TypeName #> | ConvertTo-Html -Fragment -As Table | Write-Response
      
    "<h2>Context.RequestServices</h2>" | Write-Response
    $HttpContext.RequestServices  | Select * | ConvertTo-Html -Fragment -As List  | Write-Response
     "<h2>Context.RequestServices Members</h2>" | Write-Response
	 $HttpContext.RequestServices  | Select * -First 1 | Get-Member | Where Name -notin @('Equals','GetHashCode','GetType','ToString') | Select Name,Definition,MemberType <#,TypeName #> | ConvertTo-Html -Fragment -As Table | Write-Response
         
    "<h2>Context.RequestAborted</h2>" | Write-Response
    $HttpContext.RequestAborted  | Select * | ConvertTo-Html -Fragment -As List  | Write-Response
    "<h2>Context.RequestAborted Members</h2>" | Write-Response
	$HttpContext.RequestAborted  | Select * -First 1 | Get-Member | Where Name -notin @('Equals','GetHashCode','GetType','ToString') | Select Name,Definition,MemberType <#,TypeName #> | ConvertTo-Html -Fragment -As Table | Write-Response
    
    "<h2>Context.Session</h2>" | Write-Response
    $HttpContext.Session | Get-Member  | Where Name -notin @('Equals','GetHashCode','GetType','ToString')  | Select Name,Definition,MemberType <#,TypeName #> | ConvertTo-Html -Fragment -As List  | Write-Response
    $HttpContext.Session.Keys | ConvertTo-Html -Fragment -As List  | Write-Response
   
	"<h2>Context.WebSocketRequestedProtocols</h2>" | Write-Response
    $HttpContext.WebSocketRequestedProtocols  | Select * | ConvertTo-Html -Fragment -As List  | Write-Response
    if ($HttpContext.WebSocketRequestedProtocols) { $HttpContext.WebSocketRequestedProtocols  | Select * -First 1 | Get-Member | Where Name -notin @('Equals','GetHashCode','GetType','ToString') | Select Name,Definition,MemberType <#,TypeName #> | ConvertTo-Html -Fragment -As Table | Write-Response }
    
	"<h2>Assemblies" | Write-Response
	[System.AppDomain]::CurrentDomain.GetAssemblies() | Foreach { [pscustomobject]@{Name=$_.GetName().Name;Location=$_.Location} } | Sort Name | ConvertTo-Html -Fragment -As Table | Write-Response
    
	"<h2>Assemblies ExportedTypes" | Write-Response
	[System.AppDomain]::CurrentDomain.GetAssemblies() | Foreach { if ( $_.ExportedTypes ) { $_.ExportedTypes | Select FullName } }  | Sort FullName | ConvertTo-Html -Fragment -As Table | Write-Response
    
	[AppDomain]::Currentdomain.GetAssemblies() | ? { -not $_.IsDynamic } | Select ManifestModule, FullName, Location | Sort ManifestModule | ConvertTo-Html -f | Write-Response

	$Delegates=[AppDomain]::Currentdomain.GetAssemblies() | ? { -not $_.IsDynamic } | % { 
		$_.GetExportedTypes() | ? { $_.IsPublic -and $_.BaseType -match "Delegate" } |% { $_ }
	}
	"<html><body>" | Write-Response
	$Delegates | Group Location | Foreach {
		"<h3>{0}</h3>" -f $_.Name | Write-Response
		$_.Group | Select Name, Namespace, BaseType, FullName | ConvertTo-Html -f | Write-Response

	}
	@"
	
	<!-- jQuery (necessary for Bootstrap's JavaScript plugins) -->
	<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js">
	</script>
	<!-- Include all compiled plugins (below), or include individual files as needed -->

	<!-- Latest compiled and minified JavaScript -->
	<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js" integrity="sha384-0mSbJDEHialfmuBBQP6A4Qrprq5OVfW37PRR3j5ELqxss1yVqOtnepnHVP9aJ7xS" crossorigin="anonymous">
	</script>


</body>
</html>
"@ | Write-Response
	
    Write-Warning "this is a warning test"
    Write-Verbose "this is a verbose test"
    "Tototototototototototototot"
}
catch {
	Write-ErrorResponse $_
}