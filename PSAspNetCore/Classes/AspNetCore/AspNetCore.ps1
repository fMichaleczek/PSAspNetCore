using namespace System.Reflection
using namespace System.Threading
using namespace System.Threading.Tasks

class AspNetReflection {

    static [type[]] GetOptionsType() {
        return [AppDomain]::CurrentDomain.GetAssemblies().Where{-not $_.IsDynamic}.ExportedTypes.Where{
            $_.Name -match 'options$'
        }
    }
    
    static [type[]] GetAbstrationsType() {
        return [AppDomain]::CurrentDomain.GetAssemblies().Where{-not $_.IsDynamic}.ExportedTypes.Where{
            $_.IsInterface -and
            $_.Namespace -like "Microsoft.*"
        }
    }

    static [psobject[]] GetExtensionMethod() {
        return $null
    }
    
    static [psobject[]] GetFields([object]$Object) {
        $Fields = $Object.GetType().GetFields([BindingFlags]'Public, Instance')
        if ($null -eq $Fields) {
            $Fields = $Object.GetType().GetFields([BindingFlags]'NonPublic, Instance')
        }
        return $Fields.Foreach{ 
            [PSCustomObject]@{ 
                Name = $_.Name
                Value = $_.GetValue($Object) 
                Field = $_
            } 
        }
    }
    
    static [psobject] GetFieldValue([psobject]$Object, [string]$Name) {
        return [AspNetReflection]::GetFields($Object).Where{$_.Name -eq $Name}[0].Value
    }
    
    static SetFieldValue([psobject]$Object, [string]$Name, [object]$Value) {
        [AspNetReflection]::GetFields($Object).Where{$_.Name -eq $Name}[0].Field.SetValue($Object,$Value)
    }
    
    static [object] InvokeStaticGenericMethod(
        [type]$Type, 
        [string]$MethodName, 
        [BindingFlags]$BindingFlags,
        [Type[]]$Arguments, 
        [Object[]]$Parameters
    ) {
        Write-Debug "Invoke Static Generic Method : [$Type]::$MethodName"
        
        $Methods = $Type.GetMethods($BindingFlags)
        
        $Method = $Methods.Where{
            $_.Name -eq $MethodName -and 
            $_.IsGenericMethod -and 
            $_.GetGenericArguments().Count -eq $Arguments.Count -and  
            $_.GetParameters().Count -eq $Parameters.Count
        }[0]
        
        if ($null -eq $Method) {
            Throw "Generic Method '$MethodName' not found on type '$Type'"
        }
        else {
            try {
                $GenericMethod = $Method.MakeGenericMethod($Arguments)
                return $GenericMethod.Invoke($null, $Parameters)
            }
            catch {
                Throw "Generic Method '$MethodName' on type '$Type' Error : $($_.Exception.ToString())"
            }
        }
        return $null
    }
    

}

class PSWebHost : IWebHost {
      
    # Private Properties
    
    [RequestDelegate] $Application
    
    [ApplicationLifetime] $ApplicationLifetime
    
    [IServiceProvider] $ApplicationServices
    
    [IServiceCollection] $ApplicationServiceCollection
    
    [IServiceProvider] $HostingServiceProvider
    
    [HostedServiceExecutor] $HostedServiceExecutor
    
    [AggregateException] $HostingStartupErrors
    
    [WebHostOptions] $Options
    
    [IConfiguration] $Config
    
    [IStartup] $Startup
    
    [Microsoft.Extensions.Logging.ILogger[PSWebHost]] $Logger
    
    [bool] $Stopped
    
    # Public Properties
    
    [IServer] $Server
    
    
    # Public Getter Method
    
    [WebHostOptions] get_Options() {
        Write-Verbose "PSWebHost > get_Options()"
        return $this.Options
    }
    
    [IFeatureCollection] get_ServerFeatures() {
        Write-Verbose "PSWebHost > get_ServerFeatures()"
        if ($null -eq $this.Server) {
            return $null
        }
        return $this.Server.Features
    }
    
    [IServiceProvider] get_Services() {
        Write-Verbose "PSWebHost > get_Services()"
        return $this.ApplicationServices
    }

    
    # Constructor 
    
    PSWebHost([IServiceCollection] $AppServices, [IServiceProvider] $HostingServiceProvider, [WebHostOptions] $Options, [IConfiguration] $Config, [AggregateException] $HostingStartupErrors) {
        
        Write-Verbose "PSWebHost > Instance"
        
        if ( $null -eq $AppServices ) {
            throw 'ArgumentNullException IServiceCollection'
        }
        
        if ( $null -eq $HostingServiceProvider) {
            throw 'ArgumentNullException IServiceProvider'
        }
        
        if ( $null -eq $Config) {
            throw 'ArgumentNullException IConfiguration'
        }
        
        $this.Config = $Config
        
        $this.HostingStartupErrors = $HostingStartupErrors
        
        $this.Options = $Options
        
        $this.ApplicationServiceCollection = $AppServices
        
        $this.HostingServiceProvider = $HostingServiceProvider
        
        $this.ApplicationServiceCollection.AddSingleton([IApplicationLifetime], [ApplicationLifetime])
        
        $this.ApplicationServiceCollection.AddSingleton([HostedServiceExecutor], [HostedServiceExecutor])
        
    }

    
    # Public Method
    
    Initialize() {
    
        Write-Verbose "PSWebHost > Initialize"
        if ($null -eq $this.Application) {
            $this.Application = $this.BuildApplication()
        }
        
    }

    Start() {    
    
        Write-Verbose "PSWebHost > Start"
        
        $task = $this.StartAsync([CancellationToken]::new($false))
        $Result = $task.GetAwaiter().GetResult()
        if ($task.Exception -ne $null){ 
            throw $task.Exception 
        }
        
    }

    [Task] StartAsync([CancellationToken] $CancellationToken) {
    
        Write-Verbose "PSWebHost > Start Async"
        
        $this.Initialize()
        
        Write-Host "PSWebHost > Start Async > Preparing Logging"
        [HostingEventSource]::Log.HostStart()
        $this.Logger = $this.ApplicationServices.GetRequiredService([Microsoft.Extensions.Logging.ILogger[PSWebHost]])
        
        $HostingLoggerExtensionsType = [StartupLoader].Assembly.GetType('Microsoft.AspNetCore.Hosting.Internal.HostingLoggerExtensions')
        $HostingLoggerExtensionsType::Starting($this.Logger)
        
        Write-Host "PSWebHost > Start Async > Preparing Hosting App"
        $this.ApplicationLifetime = $this.ApplicationServices.GetRequiredService([IApplicationLifetime]) -as [ApplicationLifetime]
        $this.HostedServiceExecutor = $this.ApplicationServices.GetRequiredService([HostedServiceExecutor])
        $RequiredServiceDiagnostic = $this.ApplicationServices.GetRequiredService([DiagnosticListener])
        $RequiredServiceContext = $this.ApplicationServices.GetRequiredService([IHttpContextFactory])
        $HostingApplication = [HostingApplication]::new(
            $this.Application, 
            $this.Logger, 
            $RequiredServiceDiagnostic, 
            $RequiredServiceContext
        )
        
        Write-Host "PSWebHost > Start Async > Start Async Server"
        $ServerTask = $this.Server.StartAsync($HostingApplication, $CancellationToken) # .ConfigureAwait($false) > $null
        if ($ServerTask.Exception -ne $null){ 
            throw $ServerTask.Exception 
        }
        
        if ( $null -ne $this.ApplicationLifetime) {
            $this.ApplicationLifetime.NotifyStarted()
        }
        
        Write-Host "PSWebHost > Start Async > Start Async Hosted Service Executor"
        $ServiceTask = $this.HostedServiceExecutor.StartAsync($CancellationToken) #.GetAwaiter().GetResult()
        if ($ServiceTask.Exception -ne $null){ 
            throw $ServiceTask.Exception 
        }
        
        Write-Host "PSWebHost > Start Async > Logger Started"
        
        # BUG : $this._logger.Started()
        $HostingLoggerExtensionsType::Started($this.Logger)
        
        if ( $this.Logger.IsEnabled([Microsoft.Extensions.Logging.LogLevel]::Debug) ) {
            foreach ($HostingStartupAssembly in $this.Options.HostingStartupAssemblies) {
                $this.Logger.LogDebug("Loaded hosting startup assembly {assemblyName}", $HostingStartupAssembly)
            }
        }
        
        Write-Host "PSWebHost > StartAsync > Hosting Startup Errors"
        if ( $null -ne $this.HostingStartupErrors) {
            foreach ($InnerException in $this.HostingStartupErrors.InnerExceptions) {
                $this.Logger.HostingStartupAssemblyError($InnerException)
            }
        }
        
        Write-Verbose "PSWebHost > Start Async > END"
        
        return $ServerTask
    }

    [Task] StopAsync([CancellationToken] $CancellationToken) {
    
        Write-Verbose "PSWebHost > Stop Async"
        
        if ($this.Stopped) {
            return $null
        }
        
        $this.Stopped = $true
        
        if ($null -ne $this.Logger) {
            $this.Logger.Shutdown()
        }
        
        $Task = $null
        
        $Token = [CancellationTokenSource]::new($this.Options.ShutdownTimeout).Token
        
        $CancellationToken = 
            if ( $CancellationToken.CanBeCanceled ) {
                [CancellationTokenSource]::CreateLinkedTokenSource($CancellationToken, $Token).Token
            }
            else {
                $Token
            }
        
        if ($null -ne $this.ApplicationLifetime) {
            $Task = $this.ApplicationLifetime.StopApplication()
        }
        
        if ($null -ne $this.Server) {
            $this.Server.StopAsync($CancellationToken).ConfigureAwait($false) > $null
        }
        
        if ($null -ne $this.HostedServiceExecutor) {
            $this.HostedServiceExecutor.StopAsync($CancellationToken).ConfigureAwait($false) > $null
        }
        
        if ($null -ne $this.ApplicationLifetime) {
            $this.ApplicationLifetime.NotifyStopped()
        }
        
        [HostingEventSource]::Log.HostStop()
        
        return $Task
    }

    Dispose() {
    
        Write-Verbose "PSWebHost > Dispose"
        
        if ( -not $this.Stopped) {
            try {
                $this.StopAsync().GetAwaiter().GetResult();
            }
            catch {
                if ($null -ne $this.Logger) {
                    $this.Logger.ServerShutdownException($_.Exception)
                }
            }
        }
        
        if ( $null -ne $this.ApplicationServices ) {
            $this.ApplicationServices.Dispose()
        }
        
        if ( $null -eq $this.HostingServiceProvider ) {
            $this.HostingServiceProvider.Dispose()
        }
        
    }
    
    
    # Private Method
    
    EnsureStartup() {
    
        Write-Verbose "PSWebHost > Ensure Startup"
        
        if ( $null -eq $this.Startup) {
            try {
                $this.Startup = $this.HostingServiceProvider.GetRequiredService([IStartup])
            }
            catch {
                throw "No startup configured. Please specify startup via WebHostBuilder.UseStartup, WebHostBuilder.Configure, injecting [IStartup] or specifying the startup assembly via [WebHostDefaults.StartupAssemblyKey] in the web host configuration."
            }
        }
        
    }

    EnsureApplicationServices() {
    
        Write-Verbose "PSWebHost > Ensure Application Services"
        
        if ( $null -eq $this.ApplicationServices ) {
        
            $this.EnsureStartup()
            $this.ApplicationServices = $this.Startup.ConfigureServices($this.ApplicationServiceCollection)
            
        }
        
    }

    EnsureServer() {
    
        Write-Verbose "PSWebHost > Ensure Server"
        
        if ($null -eq $this.Server) {
            
            $this.Server = $this.ApplicationServices.GetRequiredService([IServer])
            if ( $null -eq $this.Server) { throw "EnsureServer : No IServer" }

            $ServerAddressesFeature = $null
            
            if ($null -ne $this.Server.Features) {
                # BUG : $this.Server.Features.Get([Microsoft.AspNetCore.Hosting.Server.Features.IServerAddressesFeature])
                $GenericType = [Microsoft.AspNetCore.Hosting.Server.Features.IServerAddressesFeature]
                $ServerAddressesFeature = [FeatureCollection].GetMethod('Get').MakeGenericMethod($GenericType).Invoke($this.Server.Features, $null)
            }
                
            $Addresses = $null 
            
            if ( $null -ne $ServerAddressesFeature ) { 
                $Addresses = $ServerAddressesFeature.Addresses 
            } 
                
            if ($null -ne $Addresses -and -not $Addresses.IsReadOnly -and $Addresses.Count -eq 0) {
                
                $Urls = $this.Config[[WebHostDefaults]::ServerUrlsKey]
                
                if ( -not [string]::IsNullOrEmpty($Urls) ) {
                    $ServerAddressesFeature.PreferHostingUrls = [WebHostUtilities]::ParseBool($this.Config, [WebHostDefaults]::PreferHostingUrlsKey)
                    foreach ( $value in $Urls.Split(';', [StringSplitOptions]::RemoveEmptyEntries) ) {
                        $Addresses.Add($value)
                    }
                }
                
            }
        }
    }
    
    [RequestDelegate] BuildApplication() {
    
        Write-Verbose "PSWebHost > Build Application"
        
        $this.EnsureApplicationServices()
        
        $this.EnsureServer()
    
        if ( $null -eq $this.ApplicationServices ) {
            $this.ApplicationServices = $this.ApplicationServiceCollection.BuildServiceProvider()
        }
            
        if ( $null -eq $this.Logger) {
            $this.Logger = $this.ApplicationServices.GetRequiredService([Microsoft.Extensions.Logging.ILogger[PSWebHost]])
        }

        $BuilderFactory = $this.ApplicationServices.GetRequiredService([IApplicationBuilderFactory])
        
        $Builder = $BuilderFactory.CreateBuilder($this.Server.Features)
        
        $Builder.ApplicationServices = $this.ApplicationServices
        
        Write-Verbose "PSWebHost > Build Application > Invoke Startup Filter"
        
        $Configure = [Action[IApplicationBuilder]]{
            param($AppBuilder)
            $this.Startup.Configure($AppBuilder)
        }
        
        
        # $StartupFilters = @( $this.ApplicationServices.GetService([System.Collections.Generic.IEnumerable[IStartupFilter]]) )
        <#
        foreach ($Filter in [Array]::Reverse($StartupFilters) ) {
            try {    
                $Configure = $Filter.Configure($Configure)
            }
            catch {
                [Microsoft.Extensions.Logging.LoggerExtensions]::LogCritical(
                    $this.Logger, [EventId] 6,  $_.Exception, "Application startup exception : Configure", @()
                )
            }
        }
        #>
        
        Write-Verbose "PSWebHost > Build Application > Invoke Configure"
        try {
            $Configure.Invoke($Builder)
        }
        catch {
            [Microsoft.Extensions.Logging.LoggerExtensions]::LogCritical(
                $this.Logger, [EventId] 6,  $_.Exception, "Application startup exception : Invoke Configure", @()
            )
        }
        
        Write-Verbose "PSWebHost > Build Application > Build"
        try {
            $App = $Builder.Build()
        }
        catch {
        
            if ( -not $this.Options.SuppressStatusMessage ) {
                # Write errors to standard out so they can be retrieved when not in development mode.
                Write-Host "Application startup exception: $($_.Exception).ToString()"
            }
            
            [Microsoft.Extensions.Logging.LoggerExtensions]::LogCritical(
                $this.Logger, [EventId] 6,  $_.Exception, "Application startup exception : Build", @()
            )
            
            if ( -not $this.Options.CaptureStartupErrors ) {
                throw
            }
            
            $HostingEnv = $this.ApplicationServices.GetRequiredService([IHostingEnvironment])
            
            $ShowDetailedErrors = $HostingEnv.IsDevelopment() -or  $this.Options.DetailedErrors
            
            $Model = @{
                RuntimeDisplayName = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
                RuntimeArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
                ClrVersion = [AssemblyName]::new([System.ComponentModel.DefaultValueAttribute].Assembly.FullName).Version.ToString()
                OperatingSystemDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
                CurrentAssemblyVersion = [IApplicationBuilder].Assembly.GetCustomAttributes([AssemblyInformationalVersionAttribute], $true).InformationalVersion
            }
            
            return [RequestDelegate]{
                param($context)
                $Context.Response.StatusCode = 500
                $Context.Response.Headers['Cache-Control'] = 'no-cache'
                $Context.Response.Write("Error 500")
                return $Context
            }
        }
        
        Write-Verbose "PSWebHost > Build Application > END"
        return $App
    }

    
    # Public Static Method
    
    static [IWebHost] Start([RequestDelegate] $App) {
        return [PSWebHost]::Start($null, $App)
    }
    static [IWebHost] Start([string]$Url, [RequestDelegate] $App) {    
        $Name = $App.GetMethodInfo().DeclaringType.GetTypeInfo().Assembly.GetName().Name
        return [PSWebHost]::StartWith($Url, $null, [Action[IApplicationBuilder]]{ 
            param($App)
            $App.Run($App)
        }, $Name)
        
    }

    static [IWebHost] Start([Action[IRouteBuilder]] $RouteBuilder) {
        return [PSWebHost]::Start($null, $RouteBuilder)
    }
    static [IWebHost] Start([string]$Url, [Action[IRouteBuilder]] $RouteBuilder) {
    
        $ApplicationName = $RouteBuilder.GetMethodInfo().DeclaringType.GetTypeInfo().Assembly.GetName().Name
        
        $App = [Action[IApplicationBuilder]]{
            param($App)
            $App.UseRouter($RouteBuilder)
        }
        
        return [PSWebHost]::StartWith($Url, [Action[IServiceCollection]]{
            param($services)
            $services.AddRouting()
        }, $App, $ApplicationName)
        
    }

    static [IWebHost] StartWith([Action[IApplicationBuilder]] $App) {
        return [PSWebHost]::StartWith($null, $App)
    }
    static [IWebHost] StartWith([string]$Url, [Action[IApplicationBuilder]] $App) {
        return [PSWebHost]::StartWith($Url, $null, $App, $null)
    }
    static [IWebHost] StartWith([string]$Url, [Action[IServiceCollection]] $ConfigureServices, [Action[IApplicationBuilder]] $App, [string] $ApplicationName) {
        
        Write-Verbose "PSWebHost > Start With"
        
        $DefaultBuilder = [PSWebHost]::CreateDefaultBuilder()
        
        if ( -not [string]::IsNullOrEmpty($Url) ) {
            $DefaultBuilder.UseUrls($Url)
        }
        
        if ( $null -ne $ConfigureServices ) {
            $DefaultBuilder.ConfigureServices($ConfigureServices)
        }
        
        $DefaultBuilder.Configure($App)
        
        if ( -not [string]::IsNullOrEmpty($ApplicationName) ) {
           $DefaultBuilder.UseSetting([WebHostDefaults]::ApplicationKey, $ApplicationName)
        }
        
        $WebHost = $DefaultBuilder.Build()
        
        $WebHost.Start()
        
        return $WebHost
    }

    static [IWebHostBuilder] CreateDefaultBuilder() {
        return [PSWebHost]::CreateDefaultBuilder([string[]] $null)
    }
    static [IWebHostBuilder] CreateDefaultBuilder([string[]] $args) {
    
        Write-Verbose "PSWebHost > Create Default Builder > BEGIN"
        
        $HostBuilder = [PSWebHostBuilder]::new()
        
        $HostBuilder.UseKestrel()
        
        $HostBuilder.UseContentRoot($pwd)
        
        $ConfigureDelegate = [Action[WebHostBuilderContext, IConfigurationBuilder]]{
            param($HostContext, $Config)
            
            $Environment = $HostContext.HostingEnvironment
            
            $Config.AddJsonFile("appsettings.json", $true, $true)
            
            $Config.AddJsonFile("appsettings.{$($HostingEnvironment.EnvironmentName)}json", $true, $true)
            
            if ( $Environment.IsDevelopment() ) {
                # $ConfigurationBuilder.AddUserSecrets($Assembly, $true)
            }
            
            $Config.AddEnvironmentVariables()
            
            # $Config.AddCommandLine($args)
            
        }
        $HostBuilder.psbase.ConfigureAppConfiguration($ConfigureDelegate)
        
        $ConfigureLogging = [Action[[WebHostBuilderContext],[ILoggingBuilder]]]{
            param($HostContext, $Logging) 
            # BUG : $LoggingBuilder.AddConfiguration($HostContext.Configuration.GetSection("Logging"))
            [Microsoft.Extensions.Logging.LoggingBuilderExtensions]::AddConfiguration($Logging, $HostContext.Configuration.GetSection("Logging"))
            # BUG : $LoggingBuilder.AddConsole()
            [Microsoft.Extensions.Logging.ConsoleLoggerExtensions]::AddConsole($Logging)
            # BUG : $LoggingBuilder.AddDebug()
            [ Microsoft.Extensions.Logging.DebugLoggerFactoryExtensions]::AddDebug($Logging)
        }
        $HostBuilder.ConfigureLogging($ConfigureLogging)
        
        $HostBuilder.UseIISIntegration()
        
        $Configure = [Action[[WebHostBuilderContext], [ServiceProviderOptions]]]{
            param($HostContext, $ServiceProviderOptions)
            $ServiceProviderOptions.ValidateScopes = $HostContext.HostingEnvironment.IsDevelopment()
        }
        $HostBuilder.UseDefaultServiceProvider($Configure)
        
        Write-Verbose "PSWebHost > Create Default Builder > END"
        
        return     $HostBuilder
    }

    
}

class PSWebHostBuilder : WebHostBuilder {

    # Constructor
    
    PSWebHostBuilder() {
    
        Write-Verbose "PSWebHostBuilder > Instance"
        $this.SetFieldValue('_hostingEnvironment', 
            [Microsoft.AspNetCore.Hosting.Internal.HostingEnvironment]::new()
        )
        
        $this.SetFieldValue('_configureServicesDelegates', 
            [System.Collections.Generic.List[Action[[WebHostBuilderContext], [IServiceCollection]]]]::new()
        )
        
        $this.SetFieldValue('_configureAppConfigurationBuilderDelegates', 
            [System.Collections.Generic.List[Action[[WebHostBuilderContext], [IConfigurationBuilder]]]]::new()
        )
        
        $ConfigBuilder = [ConfigurationBuilder]::new()
        
        $ConfigBuilder.AddEnvironmentVariables('ASPNETCORE_')
        
        $Config = $ConfigBuilder.Build()
        
        $this.SetFieldValue('_config', $Config )
        
        if ( [string]::IsNullOrEmpty($this.GetSetting([WebHostDefaults]::EnvironmentKey))) {
            $this.UseSetting([WebHostDefaults]::EnvironmentKey,    [Environment]::GetEnvironmentVariable('ASPNET_ENV'))
        }
        
        if ( [string]::IsNullOrEmpty($this.GetSetting([WebHostDefaults]::ServerUrlsKey))) {
            $this.UseSetting([WebHostDefaults]::ServerUrlsKey, [Environment]::GetEnvironmentVariable('ASPNETCORE_SERVER.URLS'))
        }
        
        $Context = [WebHostBuilderContext]@{ 
            Configuration = $this.GetFieldValue('_config') 
        }
        $this.SetFieldValue('_context', $Context)
        
    }

    
    # Base Proxy Private Method
    hidden [psobject] GetFieldValue([string]$Name) {
        return [WebHostBuilder].GetField($Name, [BindingFlags]'NonPublic, Instance').GetValue(([WebHostBuilder]$this))
    }
    
    hidden SetFieldValue([string]$Name, [psobject]$Value) {
        [WebHostBuilder].GetField($Name, [BindingFlags]'NonPublic, Instance').SetValue(([WebHostBuilder]$this), $Value)
    }    

    
    # Private Method
    
    hidden [IServiceCollection] BuildCommonServices([ref] $hostingStartupErrors) {
    
        Write-Verbose "PSWebHostBuilder > Build Common Services"
        
        $HostingStartupErrors = $null
        
        # Options
        if ( $null -ne $this.GetFieldValue('_options') ) {
            $Options = [WebHostOptions]::new($this.GetFieldValue('_options'))
        }
        else {
            $Options = [WebHostOptions]::new()
        }
        
        $this.SetFieldValue('_options', $Options)
        
        $Options.ApplicationName = 'KitchenAspNet'
                
        if ( -not $Options.PreventHostingStartup ) {
        
            $HostingStartupAssembly = $null
            
            $ExceptionList = [System.Collections.Generic.List[Exception]]::new()
            
            try {
                # Class Loading
            }
            catch {
                $ExceptionMsg = "Startup assembly {0} failed to execute. See the inner exception for more details." -f $HostingStartupAssembly
                $ExceptionList.Add([InvalidOperationException]::new($ExceptionMsg, $_.Exception))
            }
            
            if ( $ExceptionList.Count -gt 0 ) {
                $hostingStartupErrors = [AggregateException]::new($ExceptionList)
            }
            
        }
        
        # Hosting
        
        $HostingEnvironment = $this.GetFieldValue('_hostingEnvironment')
        
        # Initialize the hosting environment
        $HostingEnvironment.Initialize(
            $Options.ApplicationName,
            $this.ResolveContentRootPath($Options.ContentRootPath, $global:ExecutionContext.SessionState.Path.CurrentFileSystemLocation.Path),
            $Options
        )
        
        $HostingEnvironment.EnvironmentName = 'Development'
        
        $this.SetFieldValue('_hostingEnvironment', $HostingEnvironment)
        
        # Context
        
        $Context = $this.GetFieldValue('_context')
        
        $Context.HostingEnvironment = $HostingEnvironment
        
        $this.SetFieldValue('_context', $Context)
        
        # Building Services
        $Services = [ServiceCollection]::new()
        
        $Services.AddSingleton($Options)
        
        $Services.AddSingleton([IHostingEnvironment], $HostingEnvironment)
        
        $Services.AddSingleton([WebHostBuilderContext], $Context)
     
        # Building Configuration 
        $Builder = [ConfigurationBuilder]::new()
        
        $Builder.SetBasePath($HostingEnvironment.ContentRootPath)
        
        $Builder.AddInMemoryCollection()
        # $Builder.AddInMemoryCollection($Config.AsEnumerable())
        
        # Execute AppConfiguration Builder Delegates
        foreach ($ConfigureAppConfiguration in $this.GetFieldValue('_configureAppConfigurationBuilderDelegates') ) {
            $ConfigureAppConfiguration.Invoke($Context, $Builder)
        }
        $this.SetFieldValue('_context', $Context)
        
        # Configuration
        $Configuration = $Builder.Build()
        
        
        $Services.AddSingleton([IConfiguration], $Configuration)
        
        ($this.GetFieldValue('_context')).Configuration = $Configuration
        
        # Add Diagnostic
        $Listener = [DiagnosticListener]::new('Microsoft.AspNetCore')
        
        $Services.AddSingleton([DiagnosticListener], $Listener)
        
        $Services.AddSingleton([DiagnosticSource], $Listener)
        
        # Add Base Factory
        $Services.AddTransient([IApplicationBuilderFactory], [ApplicationBuilderFactory])
        
        $Services.AddTransient([IHttpContextFactory], [HttpContextFactory])
        
        $Services.AddScoped([IMiddlewareFactory], [MiddlewareFactory])
        
        $Services.AddOptions()
        
        $Services.AddLogging()
        
        # Conjure up a RequestServices
        $Services.AddTransient([IStartupFilter], [AutoRequestServicesStartupFilter])
        
        $Services.AddTransient([Microsoft.Extensions.DependencyInjection.IServiceProviderFactory[IServiceCollection]], [DefaultServiceProviderFactory])
        
        # Ensure object pooling is available everywhere.
        $Services.AddSingleton([ObjectPoolProvider], [DefaultObjectPoolProvider])

        # Startup Loader
        $DynamicTypes = [AppDomain]::CurrentDomain.GetAssemblies().Where{$_.IsDynamic}.DefinedTypes
        $StartupType = $DynamicTypes.Where{ $_.Name -eq 'Startup' -or [IStartup].IsAssignableFrom($_) } | Select-Object -First 1
        
        if ( [IStartup].IsAssignableFrom($StartupType )) {
            $Services.AddSingleton([IStartup], $StartupType)
        }
        else {
            $StartupLoaderDelegate = [Func[IServiceProvider, IStartup]]{
                param($ServiceProvider)
                $RequiredService = $ServiceProvider.GetRequiredService([IHostingEnvironment])
                Throw 'StartupLoaderDelegate'
                return $null
            }
            $Services.AddSingleton([IStartup], $StartupLoaderDelegate)
        }
        
        # Execute Services Delegates
        foreach ($ConfigureServices  in $this.GetFieldValue('_configureServicesDelegates')) {
            try {
                $ConfigureServices.Invoke($Context, $Services)
            }
            catch {
                $_.Error | Write-Error
            }
        }
        
        return $Services
    }
    
    hidden [void] AddApplicationServices([IServiceCollection] $Services, [IServiceProvider] $HostingServiceProvider) {
    
        Write-Verbose "PSWebHostBuilder > Add Application Services"
        
        $Service = $HostingServiceProvider.psbase.GetService([DiagnosticListener])
        
        $Services.Replace([ServiceDescriptor]::Singleton([DiagnosticListener], $Service))
        
        $Services.Replace([ServiceDescriptor]::Singleton([DiagnosticSource], $Service))
    }

    hidden [string] ResolveContentRootPath([string] $ContentRootPath, [string] $basePath) {
    
        if ([string]::IsNullOrEmpty($ContentRootPath)) {
            return $basePath
        }
        
        if ([System.IO.Path]::IsPathRooted($ContentRootPath)) {
            return $ContentRootPath
        }
        
        return [System.IO.Path]::Combine([System.IO.Path]::GetFullPath($basePath), $ContentRootPath)
    }


    # Public Method
    
    # Builds the required services and an 'IWebHost' which hosts a web application
    [IWebHost] Build() {
    
        Write-Verbose "PSWebHostBuilder > Build > BEGIN"
        
        # Singleton
        if ( $this.GetFieldValue('_webHostBuilt') ) {
            Throw "InvalidOperationException : Instance Already Exist"
        }
        
        $this.SetFieldValue('_webHostBuilt', $true)
        
        # Services
        $HostingStartupErrors = $null
        
        $HostingServices  = $this.BuildCommonServices([ref]$HostingStartupErrors)
        
        $ServiceCollectionExtensionsType = [StartupLoader].Assembly.GetType('Microsoft.AspNetCore.Hosting.Internal.ServiceCollectionExtensions')
        $ApplicationServices = $ServiceCollectionExtensionsType::Clone($HostingServices)
        
        $HostingServiceProvider  = $HostingServices.BuildServiceProvider()
        
        #Warn about deprecated environment variables
        if ( -not $this.GetFieldValue('_options').SuppressStatusMessages ) {
        
            if ( $null -ne [Environment]::GetEnvironmentVariable('Hosting:Environment') ) {
                Write-Warning "The environment variable 'Hosting:Environment' is obsolete and has been replaced with 'ASPNETCORE_ENVIRONMENT'"
            }

            if ( $null -ne [Environment]::GetEnvironmentVariable('ASPNET_ENV') ) {
                Write-Warning "    The environment variable 'ASPNET_ENV' is obsolete and has been replaced with 'ASPNETCORE_ENVIRONMENT'"
            }

            if ( $null -ne [Environment]::GetEnvironmentVariable('ASPNETCORE_SERVER.URLS') ) {
                    Write-Warning "The environment variable 'ASPNETCORE_SERVER.URLS' is obsolete and has been replaced with 'ASPNETCORE_URLS'"
            }
            
        }
        
        $Logger = $HostingServiceProvider.GetRequiredService([Microsoft.Extensions.Logging.ILogger[PSWebHost]])
         
        $this.AddApplicationServices($ApplicationServices, $HostingServiceProvider)
        
        $WebHost = [PSWebHost]::new(
            $ApplicationServices, 
            $HostingServiceProvider, 
            $this.GetFieldValue('_options'), 
            $this.GetFieldValue('_config'), 
            $HostingStartupErrors
        )
        
        <#
        try {
            $WebHost.Initialize()
        }
        catch {
            throw "Can't Initialize WebHost Instance. $($_.Exception.ToString())"
        }
        #>
        
        Write-Verbose "PSWebHostBuilder > Build > END"
        
        return $WebHost
    }
    

}

class PSMvcServiceCollectionExtensions {

    static [IMvcBuilder] AddPSMvc([IServiceCollection] $Services, [Action[MvcOptions]] $SetupAction) {
        $MvcBuilder = [PSMvcServiceCollectionExtensions]::AddPSMvc($Services)
        $MvcBuilder.Services.Configure($SetupAction)
        return $MvcBuilder
    }
    
    static [IMvcBuilder] AddPSMvc([IServiceCollection] $Services) {
        Write-Verbose "Add PS Mvc"
        $Builder = [PSMvcServiceCollectionExtensions]::AddPSMvcCore($Services)
        $Builder.AddApiExplorer()
        $Builder.AddAuthorization()
        [PSMvcServiceCollectionExtensions]::AddDefaultFrameworkParts($Services, $Builder.PartManager)
        $Builder.AddFormatterMappings()
        $Builder.AddViews()
        $Builder.AddRazorViewEngine()
        $Builder.AddRazorPages()
        $Builder.AddCacheTagHelper()
        $Builder.AddDataAnnotations()
        $Builder.AddJsonFormatters()
        $Builder.AddCors()
        return [Microsoft.AspNetCore.Mvc.Internal.MvcBuilder]::new($Builder.Services, $Builder.PartManager)
    }        
    
    static [IMvcCoreBuilder] AddPSMvcCore([IServiceCollection] $Services) {
        
        Write-Verbose "Add PS Mvc Core"
        
        $ApplicationPartManager = [PSMvcServiceCollectionExtensions]::GetApplicationPartManager($Services)
        
        [PSMvcServiceCollectionExtensions]::TryAddSingleton($Services, [Microsoft.AspNetCore.Mvc.ApplicationParts.ApplicationPartManager], $ApplicationPartManager)
        
        [PSMvcServiceCollectionExtensions]::ConfigureDefaultFeatureProviders($ApplicationPartManager)
        
        [PSMvcServiceCollectionExtensions]::ConfigureDefaultServices($Services)
        
        [PSMvcServiceCollectionExtensions]::AddPSMvcCoreServices($Services)
        
        return [Microsoft.AspNetCore.Mvc.Internal.MvcCoreBuilder]::new($Services, $ApplicationPartManager)
    }
    
    static [Microsoft.AspNetCore.Mvc.ApplicationParts.ApplicationPartManager] GetApplicationPartManager([IServiceCollection] $services) {
        
        Write-Verbose "Get Application Part Manager"
        $Manager = [PSMvcServiceCollectionExtensions]::GetServiceFromCollection(
            $Services, [Microsoft.AspNetCore.Mvc.ApplicationParts.ApplicationPartManager]
        )
        
        if ( $null -eq $Manager ) {
        
            $Manager = [Microsoft.AspNetCore.Mvc.ApplicationParts.ApplicationPartManager]::new()
            
            $Environment = [PSMvcServiceCollectionExtensions]::GetServiceFromCollection($Services, [IHostingEnvironment])
            
            if ( $null -ne $Environment -and [String]::IsNullOrEmpty($Environment.ApplicationName) ) {
                return $Manager
            }
            
            if ( $false -and -not [String]::IsNullOrEmpty($Environment.ApplicationName) ) {
                
                $Parts = [Microsoft.AspNetCore.Mvc.Internal.DefaultAssemblyPartDiscoveryProvider]::DiscoverAssemblyParts($Environment.ApplicationName)
                
                foreach ($Part in $Parts) {
                    try {
                        $Manager.ApplicationParts.Add($Part)
                    }
                    catch {
                        Write-Warning "Error : Microsoft AspNetCore Mvc ApplicationParts with adding Discover Assembly Part $Part : $"
                    }
                }
                
            }
        }
        
        return $Manager
    }
    
    static ConfigureDefaultFeatureProviders([Microsoft.AspNetCore.Mvc.ApplicationParts.ApplicationPartManager] $Manager) {
        Write-Verbose "Configure Default Feature Providers"
        $ControllerFeatureProviders = $Manager.FeatureProviders.Where{$_ -is [Microsoft.AspNetCore.Mvc.Controllers.ControllerFeatureProvider]}
        if ( $ControllerFeatureProviders.Count -eq 0 ) {
            $ControllerFeatureProvider = [Microsoft.AspNetCore.Mvc.Controllers.ControllerFeatureProvider]::new()
            $Manager.FeatureProviders.Add($ControllerFeatureProvider)
        }
    }
    
    static ConfigureDefaultServices([IServiceCollection] $Services) {
        Write-Verbose "Configure Default Services"
        $Services.AddRouting()
    }
    
    static AddPSMvcCoreServices([IServiceCollection] $Services) {
        Write-Verbose "Add PS Mvc Core Services"
        $Services.TryAddEnumerable([ServiceDescriptor]::Transient([Microsoft.Extensions.Options.IConfigureOptions[MvcOptions]], [MvcCoreMvcOptionsSetup]))
        $Services.TryAddEnumerable([ServiceDescriptor]::Transient([Microsoft.Extensions.Options.IConfigureOptions[RouteOptions]], [MvcCoreRouteOptionsSetup]))
        $Services.TryAddEnumerable([ServiceDescriptor]::Transient([Microsoft.AspNetCore.Mvc.ApplicationModels.IApplicationModelProvider], [DefaultApplicationModelProvider]))
        $Services.TryAddEnumerable([ServiceDescriptor]::Transient([Microsoft.AspNetCore.Mvc.Abstractions.IActionDescriptorProvider], [ControllerActionDescriptorProvider]))
        
        $Services.TryAdd([ServiceDescriptor]::Singleton([
            Microsoft.AspNetCore.Mvc.Infrastructure.IActionDescriptorCollectionProvider], 
            [ActionDescriptorCollectionProvider]
        ))
        
        $Services.TryAdd([ServiceDescriptor]::Singleton([Microsoft.AspNetCore.Mvc.Infrastructure.IActionSelector], [ActionSelector]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([ActionConstraintCache], [ActionConstraintCache]))
        $Services.TryAddEnumerable([ServiceDescriptor]::Transient([Microsoft.AspNetCore.Mvc.ActionConstraints.IActionConstraintProvider], [DefaultActionConstraintProvider]))
        
        $Services.TryAdd([ServiceDescriptor]::Singleton([IControllerFactory], [DefaultControllerFactory]))
        $Services.TryAdd([ServiceDescriptor]::Transient([IControllerActivator], [DefaultControllerActivator]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([IControllerFactoryProvider], [ControllerFactoryProvider]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([IControllerActivatorProvider], [ControllerActivatorProvider]))
        $Services.TryAddEnumerable([ServiceDescriptor]::Transient([IControllerPropertyActivator], [DefaultControllerPropertyActivator]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([Microsoft.AspNetCore.Mvc.Infrastructure.IActionInvokerFactory], [ActionInvokerFactory]))
        $Services.TryAddEnumerable([ServiceDescriptor]::Transient(
            [Microsoft.AspNetCore.Mvc.Abstractions.IActionInvokerProvider], [ControllerActionInvokerProvider]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([ControllerActionInvokerCache], [ControllerActionInvokerCache]))
        
        $Services.TryAddEnumerable([ServiceDescriptor]::Singleton([Microsoft.AspNetCore.Mvc.Filters.IFilterProvider], [DefaultFilterProvider]))
        $Services.TryAdd([ServiceDescriptor]::Transient([RequestSizeLimitResourceFilter], [RequestSizeLimitResourceFilter]))
        $Services.TryAdd([ServiceDescriptor]::Transient([DisableRequestSizeLimitResourceFilter], [DisableRequestSizeLimitResourceFilter]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([Microsoft.AspNetCore.Mvc.ModelBinding.IModelMetadataProvider], [Microsoft.AspNetCore.Mvc.ModelBinding.Metadata.DefaultModelMetadataProvider]))
        
        $Services.TryAdd([ServiceDescriptor]::Transient(
            [Microsoft.AspNetCore.Mvc.ModelBinding.Metadata.ICompositeMetadataDetailsProvider],
            [Func[[IServiceProvider], [Microsoft.AspNetCore.Mvc.ModelBinding.Metadata.ICompositeMetadataDetailsProvider]]]{
                param($ServiceProvider)
                $ModelMetadataDetailsProviders = $ServiceProvider.GetRequiredService([Microsoft.Extensions.Options.IOptions[MvcOptions]]).Value.ModelMetadataDetailsProviders
                return [DefaultCompositeMetadataDetailsProvider]::new($ModelMetadataDetailsProviders)
            }
        ))
        
        $Services.TryAdd([ServiceDescriptor]::Singleton(
            [Microsoft.AspNetCore.Mvc.ModelBinding.IModelBinderFactory], 
            [Microsoft.AspNetCore.Mvc.ModelBinding.ModelBinderFactory]
        ))
        
        $Services.TryAdd([ServiceDescriptor]::Singleton(
            [Microsoft.AspNetCore.Mvc.ModelBinding.Validation.IObjectModelValidator], 
            [Func[[IServiceProvider], [Microsoft.AspNetCore.Mvc.ModelBinding.Validation.IObjectModelValidator]]]{
                param($ServiceProvider)
                $MvcOptions = $ServiceProvider.GetRequiredService([Microsoft.Extensions.Options.IOptions[MvcOptions]]).Value
                $ObjectModelValidator = [Microsoft.AspNetCore.Mvc.Internal.DefaultObjectValidator]::new(
                    $ServiceProvider.GetRequiredService([Microsoft.AspNetCore.Mvc.ModelBinding.IModelMetadataProvider]), 
                    $MvcOptions.ModelValidatorProviders
                )
                return $ObjectModelValidator
            }
        ))
        
        $Services.TryAdd([ServiceDescriptor]::Singleton([ClientValidatorCache],[ClientValidatorCache]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([Microsoft.AspNetCore.Mvc.ModelBinding.ParameterBinder], [Microsoft.AspNetCore.Mvc.ModelBinding.ParameterBinder]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([MvcMarkerService], [MvcMarkerService]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([ITypeActivatorCache], [TypeActivatorCache]))
        $Services.TryAdd([ServiceDescriptor]::Singleton(
            [Microsoft.AspNetCore.Mvc.Routing.IUrlHelperFactory], 
            [Microsoft.AspNetCore.Mvc.Routing.UrlHelperFactory]
        ))
        
        $Services.TryAdd([ServiceDescriptor]::Singleton([IHttpRequestStreamReaderFactory], [MemoryPoolHttpRequestStreamReaderFactory]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([IHttpResponseStreamWriterFactory], [MemoryPoolHttpResponseStreamWriterFactory]))
        
        # Bug : TryAddSingleton 
        $Services.TryAdd([ServiceDescriptor]::Singleton([System.Buffers.ArrayPool[byte]], [System.Buffers.ArrayPool[byte]]::Shared))
        $Services.TryAdd([ServiceDescriptor]::Singleton([System.Buffers.ArrayPool[char]], [System.Buffers.ArrayPool[char]]::Shared))
        
        $Services.TryAdd([ServiceDescriptor]::Singleton([ObjectResultExecutor], [ObjectResultExecutor]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([PhysicalFileResultExecutor], [PhysicalFileResultExecutor]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([VirtualFileResultExecutor], [VirtualFileResultExecutor]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([FileStreamResultExecutor], [FileStreamResultExecutor]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([FileContentResultExecutor], [FileContentResultExecutor]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([RedirectResultExecutor], [RedirectResultExecutor]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([LocalRedirectResultExecutor], [LocalRedirectResultExecutor]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([RedirectToActionResultExecutor], [RedirectToActionResultExecutor]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([RedirectToRouteResultExecutor], [RedirectToRouteResultExecutor]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([RedirectToPageResultExecutor], [RedirectToPageResultExecutor]))
        $Services.TryAdd([ServiceDescriptor]::Singleton([ContentResultExecutor], [ContentResultExecutor]))
        
        $Services.TryAdd([ServiceDescriptor]::Singleton([MvcRouteHandler], [MvcRouteHandler]))
        $Services.TryAdd([ServiceDescriptor]::Transient([MvcAttributeRouteHandler], [MvcAttributeRouteHandler]))
        
        $Services.TryAdd([ServiceDescriptor]::Singleton([MiddlewareFilterConfigurationProvider], [MiddlewareFilterConfigurationProvider]))
        
        $Services.TryAdd([ServiceDescriptor]::Singleton([MiddlewareFilterBuilder], [MiddlewareFilterBuilder]))
        
    }
    
    static AddDefaultFrameworkParts([IServiceCollection] $Services, [Microsoft.AspNetCore.Mvc.ApplicationParts.ApplicationPartManager] $PartManager) {
        Write-Verbose "Add Default Framework Parts"
        $MvcTagHelpersAssembly = [Microsoft.AspNetCore.Mvc.TagHelpers.InputTagHelper].Assembly
        $PartManager.ApplicationParts.Add([Microsoft.AspNetCore.Mvc.ApplicationParts.AssemblyPart]::new($MvcTagHelpersAssembly))
        
        $MvcRazorAssembly = [Microsoft.AspNetCore.Mvc.Razor.TagHelpers.UrlResolutionTagHelper].Assembly
        $PartManager.ApplicationParts.Add([Microsoft.AspNetCore.Mvc.ApplicationParts.AssemblyPart]::new($MvcRazorAssembly))
    }
    
    # Utils
    
    hidden static [PSObject] GetServiceFromCollection([IServiceCollection] $Services, [Type]$Type) {
        Write-Debug "Get Service From Collection : [$Type]"
        return [AspNetReflection]::InvokeStaticGenericMethod(
            [Microsoft.Extensions.DependencyInjection.MvcCoreServiceCollectionExtensions],
            'GetServiceFromCollection',
            [BindingFlags]'NonPublic, Static',
            $Type,
            @(, $Services)
        ) 
    }
    
    hidden static [psobject] TryAddSingleton([IServiceCollection] $Services, [Type]$Type, [Object[]]$Parameters) {
        Write-Debug "Try Add Singleton : [$Type]"
        return [AspNetReflection]::InvokeStaticGenericMethod(
            [Microsoft.Extensions.DependencyInjection.Extensions.ServiceCollectionDescriptorExtensions],
            'TryAddSingleton',
            [BindingFlags]'Public, Static',
            $Type,
            @(@(, $Services) + $Parameters)
        ) 
    }
    
    
}
