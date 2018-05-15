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
		
        $global:host.enternestedprompt()
        
        $Middleware = [Func[Microsoft.AspNetCore.Http.HttpContext, Func[Task], Task]][PSDelegate]{
            ( $Context, $Next ) => {

                $Context.Response.ContentType = "text/html"
                # $Context.Response.StatusCode = [System.Net.HttpStatusCode]::OK -as [Int32]
                
                $Text = "BeforeMiddleWare"
                [Microsoft.AspNetCore.Http.HttpResponseWritingExtensions]::WriteAsync($Context.Response, $Text, [System.Threading.CancellationToken]::None).GetAwaiter()
                
                [Task] $Task = $Next.Invoke()
                $Awaiter = $Task.GetAwaiter()
                
                $Text = "AfterMiddleWare"
                [Microsoft.AspNetCore.Http.HttpResponseWritingExtensions]::WriteAsync($Context.Response, $Text, [System.Threading.CancellationToken]::None).GetAwaiter()
                
                return $Task
            }
        }
		$App.Use($Middleware)
        
        $Handler = [Microsoft.AspNetCore.Http.RequestDelegate][PSDelegate]{ 
            ( $Context ) => {
                $Text = "OK"
                return [Microsoft.AspNetCore.Http.HttpResponseWritingExtensions]::WriteAsync($Context.Response, $Text, [System.Threading.CancellationToken]::None) 
            }
        }
        $App.Run($Handler)
	}
}
