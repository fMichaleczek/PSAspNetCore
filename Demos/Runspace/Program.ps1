class Program {
    
	static Main([string[]] $args) {
        [Program]::BuildWebHost($args).Start() > $null
    }
	
    hidden static [IWebHost] BuildWebHost([string[]] $args) {
        return [PSWebHost]::CreateDefaultBuilder().
				            UseStartup([Startup]).
                            UseUrls("http://*:5987").
					        Build()
	}
	
}
