class Startup : IStartup {

	[IConfiguration] $Configuration
	
	Startup([IConfiguration] $Configuration) {
		$this.Configuration = $Configuration
		$ConfigBuilder.AddJsonFile("appsettings.json", $true, $true)
	}
	
	[IServiceProvider] ConfigureServices([IServiceCollection] $Services) {
		Write-Verbose "Services Catalog available : "
		Write-Verbose ( $Services.psobject.Members.Where{$_.Name -match "^add"}.Foreach{$_.Name.Replace('Add','')} -join ", " )	
        
        # BROKEN
		# $Services.AddMvc()
		[PSMvcServiceCollectionExtensions]::AddPSMvc($Services)
		
		return $Services.BuildServiceProvider()
	}

	Configure([IApplicationBuilder] $App) {
		Write-Verbose "App Catalog available : "
		Write-Verbose ( $App.psobject.Members.Where{$_.Name -match "^use"}.Foreach{$_.Name.Replace('Use','')} -join ", " )
		
		$Env = $App.ApplicationServices.GetRequiredService([IHostingEnvironment])
		
        # Controller not working 
        
		<#
        
		$App.UseResponseCompression()
		$App.UseAuthentication()
		$App.UseIdentity()
		$App.UseMvcWithDefaultRoute()
		
		$app.UseMvc([Action[Microsoft.AspNetCore.Routing.IRouteBuilder]]{
			param($routes)
			$routes.MapRoute('default', '{controller=Home}/{action=Index}/{id?}')
		})
        
		#>
        
        
        $RunDelegate = [Microsoft.AspNetCore.Http.RequestDelegate][PSDelegate]{ 
            ( $context ) => {
                $Text = "OK"
                return [Microsoft.AspNetCore.Http.HttpResponseWritingExtensions]::WriteAsync($context.Response, $Text, [System.Threading.CancellationToken]::None) 
            }
        }
        $App.Run($RunDelegate)
	}
}
