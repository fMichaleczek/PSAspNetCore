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
                
                $Script = [IO.File]::ReadAllText("index.ps1")
                
                $ps = [powershell]::Create([System.Management.Automation.RunspaceMode]::NewRunspace)
                $result = $ps.AddScript($Script).AddParameter('HttpContext', $context).Invoke()
                $ps.Dispose()
                
                $Text = "OK"
                return [Microsoft.AspNetCore.Http.HttpResponseWritingExtensions]::WriteAsync($context.Response, $Text, [System.Threading.CancellationToken]::None) 
            }
        }
        $App.Run($RunDelegate)
	}
}
