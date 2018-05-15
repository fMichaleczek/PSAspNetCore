class Startup : IStartup {

	[IConfiguration] $Configuration
	
	Startup([IConfiguration] $Configuration) {
		$this.Configuration = $Configuration
	}
	
	[IServiceProvider] ConfigureServices([IServiceCollection] $Services) {
		
		$Services.AddLogging([Action[ILoggingBuilder]]{
			param($LoggingBuilder)
			[Microsoft.Extensions.Logging.ConsoleLoggerExtensions]::AddConsole($LoggingBuilder)
			[Microsoft.Extensions.Logging.DebugLoggerFactoryExtensions]::AddDebug($LoggingBuilder)
		})

		return $Services.BuildServiceProvider()
	}

	Configure([IApplicationBuilder] $App) {
		
		$Env = $App.ApplicationServices.GetRequiredService([IHostingEnvironment])
		
        $RunDelegate = [Microsoft.AspNetCore.Http.RequestDelegate][PSDelegate]{ 
            ( $context ) => {
                $Context.Response.ContentType = "text/html"
                $Context.Response.StatusCode = [System.Net.HttpStatusCode]::OK
                $Html = @"
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
	$( $Context )
	<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.3/jquery.min.js" ></script>
	<script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/js/bootstrap.min.js" integrity="sha384-0mSbJDEHialfmuBBQP6A4Qrprq5OVfW37PRR3j5ELqxss1yVqOtnepnHVP9aJ7xS" crossorigin="anonymous">	</script>
</body>
</html>
"@ 
                return [Microsoft.AspNetCore.Http.HttpResponseWritingExtensions]::WriteAsync($context.Response, $HTML, [System.Threading.CancellationToken]::None) 
            }
        }
        $App.Run($RunDelegate)
	}
}
