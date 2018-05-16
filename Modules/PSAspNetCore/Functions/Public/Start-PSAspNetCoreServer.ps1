function Start-PSAspNetCoreServer {
    param(
        $StartupFile = "$pwd\Startup.ps1",
        $ProgramFile = "$pwd\Program.ps1",
        $ScriptFile = "$pwd\$( Split-Path $pwd -Leaf ).ps1"
    )
    
    [IO.Directory]::SetCurrentDirectory($pwd)
    
    if ( Test-Path $StartupFile) {
        . $StartupFile
    }
    else {
        throw 'Fatal Error : Startup.ps1 not found'
    }
    
    if ( Test-Path $ScriptFile ) {
        . $ScriptFile
    }
    elseif ( Test-Path $ProgramFile ) {
        . $ProgramFile
        [Program]::Main($null)
    }
    else {
        class Program {
            
            static Main([string[]] $args) {
                [Program]::BuildWebHost($args).Start() > $null
            }
            
            hidden static [IWebHost] BuildWebHost([string[]] $args) {
                return [PSWebHost]::CreateDefaultBuilder($args).
                                    UseUrls("http://*:5987").
                                    UseStartup('Startup' -as [type]).
                                    Build()
            }
            
        }
        [Program]::Main($null)
    }

}