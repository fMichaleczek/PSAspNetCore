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
		    
        $Runner = [PSTaskRunner]::new(25)
        
        $RunDelegate = [Microsoft.AspNetCore.Http.RequestDelegate][PSDelegate]{ 
            ( $context ) => {
        
                [string] $Script = [IO.File]::ReadAllText("index.ps1")
                [scriptblock] $ScriptBlock = [scriptblock]::Create($Script)
                
                $Task = $Runner.Add($ScriptBlock, @{ HttpContext = $context }).Invoke().Task
                $Awaiter = $Task.GetAwaiter()
                
                $Text = " "
                return [Microsoft.AspNetCore.Http.HttpResponseWritingExtensions]::WriteAsync($context.Response, $Text, [System.Threading.CancellationToken]::None) 
            }
        }
        
        $App.Run($RunDelegate)
	}
}
