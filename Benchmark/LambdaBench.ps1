function Invoke-BenchmarkIterator {
    [OutputType([hashtable])]
    [CmdletBinding()]
    Param(
        [Parameter()]
        [Alias('ArraySize','Length','Size')]
        [int] $ArrayLength = 1000,
        
        [Parameter()]
        [Alias('Pass','Retry')]
        [int] $NumberOfPasses = 4,
        
        [Parameter()]
        [ValidateSet('For','Foreach','ForeachObject','ForeachMethod','ScriptBlock','Filter')]
        [string[]] $Method,
        
        [Parameter()]
        [switch] $PassThru
    )
    Begin {
    
        # Int Function
        function intForFunction {
            param(
            $int
            )
            Measure-Command{
                $total = [decimal]0
                for ($i = 0; $i -lt $int.length; $i++) {
                    $total += $int[$i]
                }
            }
        }
        function intForeachFunction {
            param(
            $int
            )
            Measure-Command{
                $total = [decimal]0
                foreach ($i in $int) {
                    $total += $i
                }
            }
        }
        function intForeachObjectFunction {
            param(
            $int
            )
            Measure-Command{
                $total = [decimal]0
                $int | Foreach-Object{
                    $total += $_
                }
            }
        }
        function intForeachMethodFunction {
            param(
            $int
            )
            Measure-Command{
                $total = [decimal]0
                $int.Foreach({
                    $total += $_
                })
            }
        }
        function intScriptBlockFunction {
            param(
            $int
            )
            Measure-Command{
                $total = [decimal]0
                $int | & { process{ $total += $_ } }
            }
        }
        function intFilterFunction {
            param(
            $int
            )
            filter FilterTest {
               $total += $_
            }
            Measure-Command{
                $total = [decimal]0
                $int | FilterTest
            }
        }
        
        # List Function
        function ListForFunction {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            Measure-Command{
                $total = [decimal]0
                for ($i = 0; $i -lt $int.length; $i++) {
                    $total += $list[$i]
                }
            }
        }
        function ListForeachFunction {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            Measure-Command{
                $total = [decimal]0
                foreach ($l in $list) {
                    $total += $l
                }
            }
        }
        function ListForeachObjectFunction {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            Measure-Command{
                $total = [decimal]0
                $list | Foreach-Object{
                    $total += $_
                }
            }
        }
        function ListForeachMethodFunction {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            Measure-Command{
                $total = [decimal]0
                $list.Foreach({
                    $total += $_
                })
            }
        }
        function ListScriptBlockFunction {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            Measure-Command{
                $total = [decimal]0
                $list | & { process{ $total += $_ } }
            }
        }
        function ListFilterFunction {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            filter FilterTest {
                    $total += $_
            }
            Measure-Command{
                $total = [decimal]0
                $list | FilterTest
            }
        }
        
        # Array Function
        function ArrayListForFunction {
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            Measure-Command{
                $total = [decimal]0
                for ($i = 0; $i -lt $int.length; $i++) {
                    $total += $arrayList[$i]
                }
            }
        }
        function ArrayListForeachFunction {
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            Measure-Command{
                $total = [decimal]0
                foreach ($al in $arrayList) {
                    $total += $al
                }
            }
        }
        function ArrayListForeachObjectFunction {
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            Measure-Command{
                $total = [decimal]0
                $arrayList | Foreach-Object{
                    $total += $_
                }
            }
        }
        function ArrayListForeachMethodFunction {
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            Measure-Command{
                $total = [decimal]0
                $arrayList.Foreach({
                    $total += $_
                })
            }
        }        
        function ArrayListScriptBlockFunction {
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            Measure-Command{
                $total = [decimal]0
                $arrayList | & { process{ $total += $_ } }
            }
        }
        function ArrayListFilterFunction {
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            filter FilterTest {
                    $total += $_
            }
            Measure-Command {
                $total = [decimal]0
                $arrayList | FilterTest
            }
        }
        
        # Int Class 
        function intForClass {
            param(
            $int
            )
            class intFor {
                static Invoke([int[]]$int) {
                    $total = [decimal]0
                    for ($i = 0; $i -lt $int.length; $i++) {
                        $total += $int[$i]
                    }
                }
            }
            Measure-Command {
                [IntFor]::Invoke($int)
            }
        }
        function intForeachClass {
            param(
            $int
            )
            class intForeach {
                static Invoke([int[]]$int) {
                    $total = [decimal]0
                    foreach ($i in $int) {
                        $total += $i
                    }
                }
            }
            Measure-Command {
                [intForeach]::Invoke($int)
            }
        }
        function intForeachObjectClass {
            param(
            $int
            )
            class intForeachObject {
                static Invoke([int[]]$int) {
                    $total = [decimal]0
                    $int | Foreach-Object{
                        $total += $_
                    }
                }
            }
            Measure-Command {
                [intForeachObject]::Invoke($int)
            }
        }
        function intForeachMethodClass {
            param(
            $int
            )
            class intForeachMethod {
                static Invoke([int[]]$int) {
                    $total = [decimal]0
                    $int.Foreach({
                        $total += $_
                    })
                }
            }
            Measure-Command {
                [intForeachMethod]::Invoke($int)
            }
        }
        function intScriptBlockClass {
            param(
            $int
            )
            class intScriptBlock {
                static Invoke([int[]]$int) {
                    $total = [decimal]0
                    $int | &{process{$total += $_}}
                }
            }
            Measure-Command {
                [intScriptBlock]::Invoke($int)
            }
        }
        function intFilterClass {
            param(
            $int
            )        
            filter FilterTest {
                $total += $_
            }
            class intFilter {
                static Invoke([int[]]$int) {
                    $total = [decimal]0
                    $int | FilterTest
                }
            }
            Measure-Command {
                [intFilter]::Invoke($int)
            }
        }

        # List Class
        function ListForClass {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            class ListFor {
                static Invoke([int[]]$int,[System.Collections.Generic.List[System.String]]$list) {
                    $total = [decimal]0
                    for ($i = 0; $i -lt $int.length; $i++) {
                        $total += $list[$i]
                    }
                }
            }
            Measure-Command {
                [ListFor]::Invoke($int,$list)
            }
        }
        function ListForeachClass {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            class ListForeach {
                static Invoke([int[]]$int,[System.Collections.Generic.List[System.String]]$list) {
                    $total = [decimal]0
                    foreach ($l in $list) {
                        $total += $l
                    }
                }
            }
            Measure-Command {
                [ListForeach]::Invoke($int,$list)
            }
        }
        function ListForeachObjectClass {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            class ListForeachObject {
                static Invoke([int[]]$int,[System.Collections.Generic.List[System.String]]$list) {
                    $total = [decimal]0
                    $list | Foreach-Object{
                        $total += $_
                    }
                }
            }
            Measure-Command {
                [ListForeachObject]::Invoke($int,$list)
            }
        }
        function ListForeachMethodClass {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            class ListForeachMethod {
                static Invoke([int[]]$int,[System.Collections.Generic.List[System.String]]$list) {
                    $total = [decimal]0
                    $list.Foreach({
                        $total += $_
                    })
                }
            }
            Measure-Command {
                [ListForeachMethod]::Invoke($int,$list)
            }
        }
        function ListScriptBlockClass {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            class ListScriptBlock {
                static Invoke([int[]]$int,[System.Collections.Generic.List[System.String]]$list) {
                    $total = [decimal]0
                    $list | & { process{ $total += $_ } }
                }
            }
            Measure-Command {
                [ListScriptBlock]::Invoke($int,$list)
            }
        }
        function ListFilterClass {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            filter ListFilterTest {
                $total += $_
            }
            class ListFilter {
                static Invoke([int[]]$int,[System.Collections.Generic.List[System.String]]$list) {
                    $total = [decimal]0
                    $List | ListFilterTest
                }
            }
            Measure-Command {
                [ListFilter]::Invoke($int,$list)
            }
        }

        # Class Array 
        function ArrayListForClass{
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            class ArrayListFor {
                static Invoke([int[]]$int,[System.Collections.ArrayList]$arrayList) {
                    $total = [decimal]0
                    for ($i = 0; $i -lt $int.length; $i++) {
                        $total += $arrayList[$i]
                    }
                }
            }
            Measure-Command {
                [ArrayListFor]::Invoke($int,$arrayList)
            }
        }
        function ArrayListForeachClass{
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            class ArrayListForeach {
                static Invoke([int[]]$int,[System.Collections.ArrayList]$arrayList) {
                    $total = [decimal]0
                    foreach ($al in $arrayList) {
                        $total += $al
                    }
                }
            }
            Measure-Command {
                [ArrayListForeach]::Invoke($int,$arrayList)
            }
        }
        function ArrayListForeachObjectClass{
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            class ArrayListForeachObject {
                static Invoke([int[]]$int,[System.Collections.ArrayList]$arrayList) {
                    $total = [decimal]0
                    $arrayList | Foreach-Object {
                        $total += $_
                    }
                }
            }
            Measure-Command {
                [ArrayListForeachObject]::Invoke($int,$arrayList)
            }
        }
        function ArrayListForeachMethodClass{
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            class ArrayListForeachMethod {
                static Invoke([int[]]$int,[System.Collections.ArrayList]$arrayList) {
                    $total = [decimal]0
                    $arrayList.Foreach({
                        $total += $_
                    })
                }
            }
            Measure-Command {
                [ArrayListForeachMethod]::Invoke($int,$arrayList)
            }
        }
        function ArrayListScriptBlockClass{
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            class ArrayListScriptBlock {
                static Invoke([int[]]$int,[System.Collections.ArrayList]$arrayList) {
                    $total = [decimal]0
                    $arrayList | & { process{ $total += $_ } }
                }
            }
            Measure-Command {
                [ArrayListScriptBlock]::Invoke($int,$arrayList)
            }
        }
        function ArrayListFilterClass{
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            filter FilterTest {
                $total += $_
            }
            class ArrayListFilter {
                static Invoke([int[]]$int,[System.Collections.ArrayList]$arrayList) {
                    $total = [decimal]0
                    $arrayList | FilterTest
                }
            }
            Measure-Command {
                [ArrayListFilter]::Invoke($int,$arrayList)
            }
        }
            
            
        function intForLambda {
            param(
            $int
            )
            Measure-Command{
                [psdelegate]{ 
                    $total = [decimal]0
                    for ($i = 0; $i -lt $int.length; $i++) {
                        $total += $int[$i] -as [decimal]
                    }
                }
                [void] $delegate.Invoke()
            }
        }
        function ListForLambda {
            param(
            $int
            )
            $list  = New-Object 'System.Collections.Generic.List`1[System.String]'
            $int | Foreach-Object { $list.Add($_)}
            Measure-Command{
                [psdelegate]{ 
                    $total = [decimal]0
                    for ($i = 0; $i -lt $int.length; $i++) {
                        $total += $list[$i] -as [decimal]
                    }
                }
                [void] $delegate.Invoke()
            }
        }
        
        function ArrayListForLambda {
            param(
            $int
            )
            $arrayList = New-Object System.Collections.ArrayList
            [Void]($int | Foreach-Object { $arrayList.Add($_) })
            Measure-Command{
                [psdelegate]{ 
                  $total = [decimal]0
                    for ($i = 0; $i -lt $int.length; $i++) {
                        $total += $arrayList[$i] -as [decimal]
                    }
                }
                [void] $delegate.Invoke()
            }
        }
        
        filter Format-Duration {
            <#
            $DurationString = [String]::Empty
            if ($_ -is [string]) {
                $String = "{0:00000000.0000}" -f $_
                $FirstString,$SecondString = $String.ToString().Split(".")
                $NewFirstString = [string]::Empty
                $Found = $false
                for($i=0;$i -lt $FirstString.Length;$i++) {
                    If ($FirstString[$i] -eq "0" -and $Found -eq $false) {
                        $NewFirstString += " "
                    }
                    else {
                        $NewFirstString += $FirstString[$i] 
                        $Found = $true
                    }
                }
                $DurationString = "{0,8}.{1:00}" -f $NewFirstString, $SecondString
            }
            return $DurationString
            #>
            $float = [float]($_.Replace(',','.'))
            [math]::Round($float, 2, [System.MidpointRounding]::ToEven)
        }
        
        filter Out-ColorWord {
            param(
                [System.Collections.IEnumerable] $Definition
            )
            [string] $Line = $_
            [string[]] $Words = $Line -split " " | Where { $_.ToString() -ne "" }
            foreach($Word in $Words) {
                $ColorWord = $Definition.Where({$_.Name -eq $Word})
                if ($ColorWord) {
                    $index = $line.IndexOf($Word, [System.StringComparison]::InvariantCultureIgnoreCase)
                    Write-Host $line.Substring(0,$index) -NoNewline
                    Write-Host $line.Substring($index, $word.Length) -NoNewline -ForegroundColor ($ColorWord.Foreground) -BackgroundColor ($ColorWord.Background)
                    $used = $word.Length + $index
                    $remain = $line.Length - $used
                    $line = $line.Substring($used, $remain)
                }
            }
            Write-Host "$line`r"
        }
        
        $Benchmark = @{
            Methods = [hashtable[]]@(
                @{ Name = "For" ; Background = "DarkBlue" ; Foreground = "White" }
                @{ Name = "Foreach" ;  Background = "DarkGreen" ; Foreground = "White" }
                @{ Name = "ForeachMethod" ;  Background = "DarkGray" ; Foreground = "White" }
                @{ Name = "ForeachObject" ;  Background = "DarkCyan" ; Foreground = "White" }
                @{ Name = "ScriptBlock" ;  Background = "DarkRed" ; Foreground = "White" }
                @{  Name = "Filter" ; Background = "DarkMagenta" ; Foreground = "White" }
            )
            Types = [hashtable[]]@(
                @{  Name = "Int" ; Background = "Green" ; Foreground = "Black" }
                @{  Name = "List" ; Background = "Yellow" ; Foreground = "Black" }
                @{  Name = "ArrayList" ; Background = "Red" ; Foreground = "Black" }
            )
            Engines = [hashtable[]]@(
                @{  Name = "Function" ; Background = "Gray" ; Foreground = "Black" }
                @{  Name = "Class" ; Background = "DarkGray" ; Foreground = "Black" }
                @{  Name = "Lambda" ; Background = "White" ; Foreground = "Black" }
            )
            NumberOfPasses = [int]$NumberOfPasses
            ArrayLength = [int]$ArrayLength
            PassReports = [psobject[]]@()
            SummaryReports = [psobject[]]@()
        }
        if ($Method) {
            $Benchmark.Methods = $Benchmark.Methods.Where({$_.Name -in $Method})
        }
        $ColorDefinition = $Benchmark.GetEnumerator().Foreach({$_.Value})
        
    }
    
    process {
    
        try {
            Write-Verbose "Building Array with size $ArrayLength ..."
            $Array = [int[]](1..$ArrayLength)
            Write-Verbose "Building done."
      
            for($pass=1 ; $pass -le $Benchmark.NumberOfPasses ; $pass++) {
                if (-not $PassThru) {
                    Write-Host "`nPass    : $Pass`r" -Background Green -Foreground DarkGreen
                }
                
                foreach($TypeName in $Benchmark.Types.Name) {
                    if (-not $PassThru) {
                        Write-Host "`nType    : $TypeName`r" -Background DarkCyan -Foreground Cyan
                    }
                    
                    [string[]] $MethodsName = (Get-Random -input $Benchmark.Methods.Name -Count $Benchmark.Methods.Name.Length )
                    foreach($MethodName in $MethodsName) {
                    
                        [string[]] $EnginesName = (Get-Random -input $Benchmark.Engines.Name -Count $Benchmark.Engines.Name.Length )
                        foreach($EngineName in $EnginesName) {
                            try {
                                $CommandName = "{0}{1}{2}" -f $TypeName,$MethodName,$EngineName
                                if ( $null -ne ( Get-Command $CommandName -EA 0 ) ) {
                                    $MeasureCommand = & ( Get-Command $CommandName ) -int $Array | Select-Object -Expand TotalMilliseconds
                                    $Result = [PSCustomObject]@{
                                        Type = $TypeName
                                        ElapsedInMsRaw = $MeasureCommand
                                        ElapsedInMs = $MeasureCommand.ToString() | Format-Duration
                                        Method = $MethodName
                                        Engine = $EngineName
                                        Pass = $Pass
                                        Function = $CommandName
                                    }
                                    if (-not $PassThru) {
                                        Write-Host ( "Command : {0,-30} Milliseconds : {1}" -f $CommandName, $Result.ElapsedInMs ) -ForegroundColor White
                                    }
                                    $Benchmark.PassReports += $Result
                                }
                            }
                            catch {
                                Write-Error  $_.Exception
                            }
                        }
                    }
                }
            }
            if (-not $PassThru) {
                Write-Host " "
            }
        }
        Catch {
            Write-Error $_.Exception
        }
    }
    
    end {
        # Make Summary Report
        foreach($TypeName in $Benchmark.Types.Name) {
            foreach($MethodName in $Benchmark.Methods.Name) {
                foreach($EngineName in $Benchmark.Engines.Name) {
                    $AllPass = $Benchmark.PassReports.Where({$_.Type -eq $TypeName -and $_.Method -eq $MethodName -and $_.Engine -eq $EngineName})
                    $Mesure = $AllPass.ElapsedInMsRaw | Measure-Object -Minimum -Average -Maximum
                    if ( $null -ne $Mesure -and $null -ne $Mesure.Average ) {
                        $SummaryReport = [PSCustomObject]@{
                            Type = $TypeName
                            Method = $MethodName
                            Engine = $EngineName
                            AverageInMs = $Mesure.Average.ToString() | Format-Duration 
                            MinimumInMs = $Mesure.Minimum.ToString() | Format-Duration
                            MaximumInMs = $Mesure.Maximum.ToString() | Format-Duration
                        }
                        $Benchmark.SummaryReports += $SummaryReport
                    }
                }
            }
        }
        
        # Clear Garbage Collector
        [GC]::Collect()
        
        # Report or PassThru
        if (-not $PassThru) {
            Write-Host "PASS REPORTS : `n" -Foreground Cyan
            $Benchmark.PassReports | Sort Type,ElapsedInMsRaw | Select -Property * -Exclude ElapsedInMsRaw | Format-Table -AutoSize | Out-String -Stream -Width $host.UI.RawUI.MaxPhysicalWindowSize.Width | Out-ColorWord -Definition $ColorDefinition
       
            Write-Host "SUMMARY REPORTS : `n" -Foreground Cyan
            Write-Host "Array Length : $ArrayLength - Number of Passes : $NumberOfPasses"
            $Benchmark.SummaryReports | Sort Type, AverageInMs | Select -Exclude ElapsedInMsRaw | Format-Table -AutoSize | Out-String -Stream -Width $host.UI.RawUI.MaxPhysicalWindowSize.Width | Out-ColorWord -Definition $ColorDefinition
        }
        else {
            return $Benchmark | Select-Object -ExcludeProperty Array
        }
    }
}
