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
		
         $RunDelegate = [Microsoft.AspNetCore.Http.RequestDelegate][PSDelegate]{ 
            ( $context ) => {
                $tId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                $Text = "OK.$tId"
                return [Microsoft.AspNetCore.Http.HttpResponseWritingExtensions]::WriteAsync($context.Response, $Text, [System.Threading.CancellationToken]::None) 
            }
        }
        $App.Run($RunDelegate)
	}
}
