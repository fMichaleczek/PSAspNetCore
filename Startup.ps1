class Startup : IStartup {

	[IConfiguration] $Configuration
	
	Startup([IConfiguration] $Configuration) {
		Write-Host "Startup > Instance" -ForegroundColor Magenta
		$this.Configuration = $Configuration
		# $ConfigBuilder.AddJsonFile("appsettings.json", $true, $true)
		# $ConfigBuilder.AddEnvironmentVariables()
	}
	
	[IServiceProvider] ConfigureServices([IServiceCollection] $Services) {
		Write-Host "Startup > Configure Services" -ForegroundColor Magenta
		Write-Host "Catalog available : " -ForegroundColor Yellow
		Write-Host ( $Services.psobject.Members.Where{$_.Name -match "^add"}.Foreach{$_.Name.Replace('Add','')} -join ", " )		
		Write-Host " "
			
		$Services.AddLogging([Action[ILoggingBuilder]]{
			param($LoggingBuilder)
			[Microsoft.Extensions.Logging.ConsoleLoggerExtensions]::AddConsole($LoggingBuilder)
			[Microsoft.Extensions.Logging.DebugLoggerFactoryExtensions]::AddDebug($LoggingBuilder)
		})
		
        # BROKEN
		# $Services.AddMvc()
		[PSMvcServiceCollectionExtensions]::AddPSMvc($Services)
		
		return $Services.BuildServiceProvider()
	}

	Configure([IApplicationBuilder] $App) {
		Write-Host "Startup > Configure Application" -ForegroundColor Magenta
		Write-Host "Catalog available : " -ForegroundColor Yellow
		Write-Host ( $App.psobject.Members.Where{$_.Name -match "^use"}.Foreach{$_.Name.Replace('Use','')} -join ", " )
		Write-Host " "
		
		$Env = $App.ApplicationServices.GetRequiredService([IHostingEnvironment])
			
		$RunDelegateSb = [Microsoft.AspNetCore.Http.RequestDelegate]{
			param([HttpContext]$Context)
			Write-Host "App.Run Start" -Background Yellow -Foreground DarkRed
            
			Write-Host "App.Run Set ContentType" -Background Yellow -Foreground DarkRed
			$Context.Response.ContentType = "text/html"
            
			Write-Host "App.Run Set StatusCode" -Background Yellow -Foreground DarkRed
			$Context.Response.StatusCode = [System.Net.HttpStatusCode]::OK
            
			$Body = @"
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
	<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css" integrity="sha384-1q8mTJOASx8j1Au+a5WDVnPi2lkFfwwEAa8hDDdjZlpLegxhjVME1fgjWPGmkzs7" crossorigin="anonymous">
	<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap-theme.min.css" integrity="sha384-fLW2N01lMqjakBkx3l/M9EahuwpSfeNvV63J5ezn3uZzapT0u7EYsXMjQV+0En5r" crossorigin="anonymous">
	<style type="text/css">
		h2 { color : #FF0000 ; padding-top : 10px ; }
		h3 { color : blue ; padding-top : 5px ; }
		table { border : 1px solid #CCCCCC !important}
		table th { background : FFCCCC ; border : 1px solid #CCCCCC !important ; padding : 5px ; font-size : 12px ; }
		table td { border : 1px solid #CCCCCC !important ; padding : 5px ; font-size : 14px ; }
		h3 { color : #FF0000 ; }
	</style>
</head>
<body>
	<h1>DEBUG</h1>
	
	RunDelegateSb. ThreadId : $([appdomain]::GetCurrentThreadId()) $([System.Threading.Thread]::CurrentThread.ManagedThreadId)
	$( $Context | Get-Member | ConvertTo-Html -Fragment -As List )
	
	<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js" ></script>
	<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js" integrity="sha384-0mSbJDEHialfmuBBQP6A4Qrprq5OVfW37PRR3j5ELqxss1yVqOtnepnHVP9aJ7xS" crossorigin="anonymous">	</script>
</body>
</html>
"@ 
            $Data = [System.Text.Encoding]::UTF8.GetBytes($Body)
            
            Write-Host "Return WriteAsync" -Background Yellow -Foreground DarkRed
			return $Context.Response.Body.WriteAsync($Data, 0, $Data.Length)
        }
        
		$Runspace = [runspacefactory]::CreateRunspace()
		$Runspace.Open()
		$RunDelegate = [PowerShell.RunspacedDelegateFactory]::NewRunspacedDelegate($RunDelegateSb, $Runspace)
		$App.Run($RunDelegate)
		
	}
}
