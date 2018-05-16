using namespace System.Management.Automation
using namespace System.Management.Automation.Host
using namespace System.Management.Automation.Runspaces
using namespace System.Reflection
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.Threading
using namespace System.Threading.Tasks

#Require 5.0


class PSTask {
	hidden static [Int] $IdCount = 0

	[int] $Id
	[string] $ScriptString
	[List[PSObject]] $ArgumentList
	[scriptblock] $ScriptBlock
	[PSTaskRunner] $Runner
	[Task] $Task
	$Result
	
	# Without Runner
	PSTask([string]$ScriptString) {
		$this.Initialize($ScriptString)
	}
	PSTask([ScriptBlock]$ScriptBlock) {
		$this.Initialize($ScriptBlock)
	}
	PSTask([ScriptBlock]$ScriptBlock, [Array]$ArgumentList) {
		$this.Initialize($ScriptBlock, $ArgumentList)
	}
	
	PSTask([ScriptBlock]$ScriptBlock, [hashtable]$ArgumentHashtable) {
		$this.Initialize($ScriptBlock,$ArgumentHashtable)
	}
	PSTask([ScriptBlock]$ScriptBlock, [PSVariable[]]$Variables) {
	   $this.Initialize($ScriptBlock,@($Variables))
	}
	
	# Runner
	PSTask([ScriptBlock]$ScriptBlock, [PSTaskRunner]$Runner) {
		$this.Initialize($ScriptBlock, $Runner)
	}
	PSTask([string]$ScriptString, [PSTaskRunner]$Runner) {
		$this.Initialize($ScriptString,$Runner)
	}
	PSTask([ScriptBlock]$ScriptBlock, [Array]$ArgumentList, [PSTaskRunner]$Runner ) {
		$this.Initialize($ScriptBlock, $ArgumentList,[PSTaskRunner]$Runner)
	}
	PSTask([ScriptBlock]$ScriptBlock, [hashtable]$ArgumentHashtable, [PSTaskRunner]$Runner) {
		$this.Initialize($ScriptBlock,$ArgumentHashtable,[PSTaskRunner]$Runner)
	}
	PSTask([ScriptBlock]$ScriptBlock, [PSVariable[]]$Variables, [PSTaskRunner]$Runner) {
	   $this.Initialize($ScriptBlock,@($Variables),[PSTaskRunner]$Runner)
	}
	
	#Initialize 
	
	hidden Initialize([ScriptBlock]$ScriptBlock, $InputObject) {
		$this.Initialize($ScriptBlock, $InputObject, $null)
    }
    hidden Initialize([ScriptBlock]$ScriptBlock, $InputObject, $Runner) {
		if ($this.Runner -eq $null -and $Runner -eq $null) {
			$this.Runner = [PSTaskRunner]::new()
		}
		else {
			$this.Runner =  $Runner
		}
		Write-Verbose "`$InputObject is $($InputObject.GetType().FullName)"
		Write-Verbose "Initialize PSTask"
		$this.Id = [PSTask]::CreateID()
		$this.ScriptString = [PSTask]::CreateScriptString($ScriptBlock, $InputObject)
		$this.ArgumentList = [PSTask]::ConvertObjectToList($InputObject)
		
		#To Improve
		$this.Runner.PSTasks.Enqueue($this)
		$this | Add-Member -Name Result -Force -MemberType ScriptProperty -Value {
			$this.Tasks.Result
		}
		$this | Add-Member -Name ScriptBlock -Force -MemberType ScriptProperty -Value {
			[scriptblock]::Create($this.ScriptString)
		}
		$DefaultDisplaySet = $this.GetType().GetProperties().Where{$_.CustomAttributes.Count -eq 0 -or ( $_.CustomAttributes.Count -gt 0 -and $_.CustomAttributes[0].AttributeType -and $_.CustomAttributes[0].AttributeType -ne [HiddenAttribute] ) }.Name
		$DefaultDisplayPropertySet = [PSPropertySet]::new('DefaultDisplayPropertySet',[string[]]$DefaultDisplaySet)
		$this | Add-Member -Name PSStandardMembers -MemberType MemberSet -Value ([PSMemberInfo[]]@($DefaultDisplayPropertySet))
    }
	
	
	hidden static [int] CreateID() {
		[PSTask]::IdCount++
        return [PSTask]::IdCount
	}
	
	hidden static [List[PSObject]] ConvertObjectToList($InputObject) {
		$List = [List[PSObject]]::new()
		switch($InputObject) {
			{ $_ -is [Array] } {
				@($_).Foreach{$List.Add($_)}
			}
			{ $_ -is [hashtable] } {
				@($_.Values).Foreach{$List.Add($_)}
			}
			{ $_ -is [PSVariable] -or $_ -is [PSVariable[]] } {
			   @($_.Name).Foreach{$List.Add($global:ExecutionContext.SessionState.PSVariable.Get($_).Value)}
			}
			default {
				$_.Foreach{$List.Add($_)}
			}
		}
		return $list
	}
	
	hidden static [string] CreateScriptString($ScriptBlock, $InputObject) {
		$String = $ScriptBlock.ToString()
		$Parameters = @()
		$InputObjectType = $InputObject.GetType()
		switch($InputObjectType) {
			{ $_ -eq [Hashtable] } {
				$Parameters = @($InputObject.Keys)
			}
			{ $_ -eq [PSVariable] -or $_ -eq [PSVariable[]] } {
			   $Parameters = @($InputObject.Name)
			}
		}
		if ($Parameters.Count -ne 0) {
		   $ParametersString = "Param({0})`n" -f ($Parameters.Foreach{"`$$_"} -join ", ")
		   $String = $ParametersString + $String
		}
		return $String
	}	
 
	[PSTask] Invoke() {
		return $this.Invoke($this)
	}
	
	[PSTask] Start() {
		[PSTask]::Start($this)
		return $this
	}
	
	[PSTask] WaitAll() {
		[PSTask]::WaitAll($this)
		return $this
	}
	
	[PSTask] WaitAny() {
		[PSTask]::WaitAny($this)
		return $this
	}
	
	
	[PSTask] Invoke([PSTask]$PSTask) {
		return [PSTaskRunner]::Invoke($PSTask.Runner, $PSTask)
	}
	
	static Start([PSTask]$PSTask) {
		[PSTaskRunner]::Start($PSTask.Runner, $PSTask)
	}
	
	static WaitAny([PSTask]$PSTask) {
		[PSTaskRunner]::WaitAny($PSTask.Runner)
	}
	
	static WaitAll([PSTask]$PSTask) {
		[PSTaskRunner]::WaitAll($PSTask.Runner)
	}
	
}


enum PSTaskRunnerSessionType {
	Default
	Default2
	Empty
	Restricted
}



class PSTaskRunner : System.IDisposable {
   
   # static Properties
   # Default Value for all instances creation. can be changed [PSTaskRunner]::DefaultApartmentState = 'MTA'
   static [PSTaskRunnerSessionType] $DefaultSessionType = [PSTaskRunnerSessionType]::Default
   static [int] $DefaultThrottle = [System.Environment]::ProcessorCount
   static [ApartmentState] $DefaultApartmentState = [ApartmentState]::STA
   static [PSThreadOptions] $DefaultPSThreadOptions = [PSThreadOptions]::ReuseThread
   static [Timespan] $DefaultCleanupInterval = [Timespan]::FromMinutes(15)
   static [IHostSupportsInteractiveSession] $DefaultPSHost = $global:host
   
   # Instance Properties Parameters 
   hidden [PSTaskRunnerSessionType] $SessionType = [PSTaskRunner]::DefaultSessionType
   hidden [int] $Throttle = [PSTaskRunner]::DefaultThrottle
   hidden [ApartmentState] $ApartmentState = [PSTaskRunner]::DefaultApartmentState
   hidden [PSThreadOptions] $PSThreadOptions = [PSTaskRunner]::DefaultPSThreadOptions
   hidden [IHostSupportsInteractiveSession] $PSHost = [PSTaskRunner]::DefaultPSHost
   hidden [Timespan] $CleanupInterval = [PSTaskRunner]::DefaultCleanupInterval
   
   # Main Instance Properties
   [InitialSessionState] $InitialSessionState
   [RunspacePool] $RunspacePool
   [List[Runspace]] $Runspaces
   [ConcurrentQueue[PSTask]] $PSTasks = [ConcurrentQueue[PSTask]]::new()
   [ConcurrentQueue[PSTask]] $PSTasksRunning = [ConcurrentQueue[PSTask]]::new()
   [ConcurrentQueue[PSTask]] $PSTasksHistory = [ConcurrentQueue[PSTask]]::new()
   
	$Result
	
   # Constructor - Arguments
   PSTaskRunner() {
        $this.Initialize()
   }
   PSTaskRunner([int]$Throttle) {
        $this.Throttle = $Throttle
        $this.Initialize()
   }
   PSTaskRunner([int]$Throttle,[ApartmentState] $ApartmentState) {
        $this.Throttle = $Throttle
        $this.ApartmentState = $ApartmentState
        $this.Initialize()
   }
   PSTaskRunner([int]$Throttle,[ApartmentState] $ApartmentState,[PSThreadOptions] $PSThreadOptions) {
        $this.Throttle = $Throttle
        $this.ApartmentState = $ApartmentState
		$this.PSThreadOptions = $PSThreadOptions
        $this.Initialize()
   }
   PSTaskRunner(
		[int]$Throttle,
		[ApartmentState] $ApartmentState,
		[PSThreadOptions] $PSThreadOptions, 
		[Timespan] $CleanupInterval
	) {
        $this.Throttle = $Throttle
        $this.ApartmentState = $ApartmentState
        $this.PSThreadOptions = $PSThreadOptions
		$this.CleanupInterval = $CleanupInterval
        $this.Initialize()
   }

   # Common Initialize (After Constructor)
   hidden Initialize() {
		# Build a InitialSessionState and a RunspacePool from Arguments
		$this.InitialSessionState = [PSTaskRunner]::CreateInitialSessionState($this.SessionType, $this.ApartmentState, $this.PSThreadOptions, $this.CleanupInterval)
        $this.RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, $this.Throttle, $this.InitialSessionState, $this.PSHost)
		
		$this.RunspacePool.CleanupInterval =  $this.CleanupInterval
		
		if ($this.RunspacePool.RunspacePoolAvailability -ne [RunspacePoolAvailability]::Available) {
			$this.RunspacePool.Open()
			[System.Threading.Thread]::Sleep(100)
		}
		
		# Add some scriptProperty to the class because we cannot create a Getter in PS 5 Class
		$Members = @{
			Runspaces = {
				$InternalPool = [RunspacePool].GetField('internalPool','NonPublic,Instance').GetValue($this.RunspacePool)
				$InternalPool.GetType().GetField('runspaceList','NonPublic,Instance').GetValue($InternalPool)
			}
			AvailableRunspaces = { $this.RunspacePool.GetAvailableRunspaces() }
			MaxRunspaces = { $this.RunspacePool.GetMaxRunspaces() }
			Result = { $this.PSTasksHistory.Task.Result }
		}
		foreach($Member in $Members.GetEnumerator()) {
			[PSTaskRunner]::AddScriptProperty($this, $Member.Name, $Member.Value)
		}
		
   }
   
	[PSTask] Add([scriptblock]$ScriptBlock) {
		$PSTask = [PSTask]::new($ScriptBlock, $this)
		$this.PSTasks.Enqueue($PSTask)
        return $PSTask
		Write-Verbose "PSTask $($PSTask.Id) Enqueued"
	}

	[PSTask] Add([scriptblock]$ScriptBlock, [Array]$List) {
	   return [PSTask]::new($ScriptBlock,$List, $this)
	}

	[PSTask] Add([scriptblock]$ScriptBlock, [hashtable]$HashTable) {
		return [PSTask]::new($ScriptBlock,$HashTable, $this)
	}

	[PSTask] Add([scriptblock]$ScriptBlock, [PSVariable[]]$Variables) {
		return [PSTask]::new($ScriptBlock,$Variables, $this)
	}

	[PSTask[]] AddPipeLine([scriptblock]$ScriptBlock, [IEnumerable]$InputObject) {
		$PSTasksBag = @()
        $InputObject.Foreach{
		   $PSTask = [PSTask]::new($ScriptBlock,@($_), $this)
		   $this.PSTasks.Enqueue($PSTask)
		   Write-Verbose "PSTask $($PSTask.Id) Enqueued"
           $PSTasksBag += $PSTask
		}
        return $PSTasksBag
	}
    
   Invoke() {
		[PSTaskRunner]::Invoke($this)
	}

   Start() {
		[PSTaskRunner]::Start($this)
   }
   
   Dispose() {
		try {
			if ($this.RunspacePool.RunspacePoolAvailability -ne [RunspacePoolAvailability]::None) {
				$this.RunspacePool.Close()
			}
			if (-not $this.RunspacePool.IsDisposed) {
				$this.RunspacePool.Dispose()
			}
        }
		catch {}
		finally {
			$this.RunspacePool = $null	
		}
		
		
        try {
			$this.PSTasks.Task.GetEnumerator().Foreach{ $_.Dispose() }
		}
		catch {}
		finally {
			    $this.PSTasks.Task = $null
		}
		
		$this.PSTasks = $null
		
		try {
			if ($null -ne $this.Result -and $this.Result.Count -gt 0 -and $this.Result[0] -Is [IDisposable]) {
				$this.Result.ForEach{ $_.Dispose() }
			}
			$this.Result = $null
		}
		catch {}
		
		[GC]::SuppressFinalize($this)
	}
   
   hidden static AddScriptProperty([PSTaskRunner]$PSTaskRunner, [string]$Name, [scriptblock] $ScriptBlock) {
		$Member = @{ 
			InputObject = $PSTaskRunner
			MemberType = 'ScriptProperty'
			Name = $Name
			Value = $ScriptBlock
			Force = $true
		}
		Add-Member @Member
   }
   
   hidden static [InitialSessionState] CreateInitialSessionState(
		[PSTaskRunnerSessionType]$SessionType, 
		[ApartmentState]$ApartmentState, 
		[PSThreadOptions] $ThreadOptions, 
		[Timespan] $CleanupInterval
	) {
        Write-Verbose "Creating InitialSessionState"
        
        # Build InitialSessionState Object
		if ($SessionType -eq [PSTaskRunnerSessionType]::Empty) {
			$InitialSessionStateMethod = 'Create'
		}
		else {
			$InitialSessionStateMethod = "Create${SessionType}"
		}
        $InitialSessionStateFactoryMethod =  [InitialSessionState].GetMethod($InitialSessionStateMethod)
        $InitialSessionStateInstance = $InitialSessionStateFactoryMethod.Invoke($null,@())
        
         # Set Default Property Value and Preference mangement variable
        $InitialSessionStateInstance.ApartmentState = $ApartmentState
        $InitialSessionStateInstance.ThreadOptions =  $ThreadOptions
		
        foreach ($Variable in @('Verbose','ErrorAction','Warning','Debug','Progress')) {
            $InitialSessionStateInstance.Variables.Add([SessionStateVariableEntry]::new(
				"${Variable}Preference",  #Name
				( Get-Variable -Name "${Variable}Preference"  -Scope 0 -ValueOnly -EA 0 ),  # Value
				'Added by TaskRunner', #Description
				[ScopedItemOptions]::AllScope #Scope
			))
        }
		
		return $InitialSessionStateInstance
   }

	hidden static [PowerShell] CreatePowerShell([PSTask]$PSTask) {
		$RunspacePoolInstance = [PSTaskRunner]::CreateRunspacePool()
		return [PSTaskRunner]::CreatePowerShell($PSTask, $RunspacePoolInstance)
	}
	hidden static [PowerShell] CreatePowerShell([PSTask]$PSTask, [RunspacePool]$RunspacePool) {
		$Powershell = [Powershell]::Create()
		
		$Powershell.RunspacePool = $RunspacePool
		
		$Powershell.AddScript($PSTask.ScriptString)
		# Add Parameters from PSTask object
		foreach($Argument in $PSTask.ArgumentList) {
			$Powershell.AddArgument($Argument)
		}
		
		return $PowerShell
	}

	
	hidden static [Delegate] CreateBeginInvokeDelegate([PowerShell]$Powershell) {
		return [PowerShell].GetMethods().Where{
			"$_" -eq (
			'System.IAsyncResult BeginInvoke[T](System.Management.Automation.PSDataCollection`1[T], ' + 
			'System.Management.Automation.PSInvocationSettings, System.AsyncCallback, System.Object)'
			)
		}.MakeGenericMethod(
			[PSObject]
		).CreateDelegate(
			[System.Func[[PSDataCollection[PSObject]],[PSInvocationSettings],[AsyncCallback],[Object],[IAsyncResult]]],
			$Powershell
		)
	}
	hidden static [Delegate] CreateEndInvokeDelegate([PowerShell]$Powershell) {
		return [PowerShell].GetMethod("EndInvoke").CreateDelegate(
			[Func[[IAsyncResult],[PSDataCollection[PSObject]]]],
			$Powershell
		) 
	}
	hidden static [Task[PSDataCollection[PSOBject]]] CreateTaskFromAsync([PowerShell]$Powershell) { 
		return [PSTaskRunner]::CreateTaskFromAsync($Powershell, [TaskCreationOptions]::None)
	}
	hidden static [Task[PSDataCollection[PSOBject]]] CreateTaskFromAsync([PowerShell]$Powershell, [TaskCreationOptions]$TaskCreationOptions) {
		$BeginInvokeDelegate = [PSTaskRunner]::CreateBeginInvokeDelegate($PowerShell)
		$EndInvokeDelegate = [PSTaskRunner]::CreateEndInvokeDelegate($PowerShell)
		$Arguments = (
			$BeginInvokeDelegate,
			$EndInvokeDelegate,
			[PSDataCollection[PSObject]]::new(),
			[PSInvocationSettings]::new(),
			$null,
			$TaskCreationOptions
		)
		$GenericMethod = [TaskFactory].GetMethods().Where{
			"$_" -eq (
				'System.Threading.Tasks.Task`1[TResult] FromAsync[TArg1,TArg2,TResult](' +
				'System.Func`5[TArg1,TArg2,System.AsyncCallback,System.Object,System.IAsyncResult], ' +
				'System.Func`2[System.IAsyncResult,TResult], TArg1, TArg2, System.Object, System.Threading.Tasks.TaskCreationOptions)'
			)
		}.MakeGenericMethod(
			[PSDataCollection[PSObject]], 
			[PSInvocationSettings], 
			[PSDataCollection[PSObject]]
		)
		return $GenericMethod.Invoke([Task]::Factory, $Arguments)
	}
	
	hidden static [List[PSDataCollection[[PSObject]]]] ConvertTaskResultToList([List[Task[PSDataCollection[PSOBject]]]]$Tasks) {
		while($Tasks.Where{$_.Status -eq [TaskStatus]::Running}) {
			[PSTaskRunner]::Delay(100)
		}
		$List = [List[PSDataCollection[[PSObject]]]]::new()
		$Tasks.Where{$_.IsCompleted -and $null -ne $_.Result}.Foreach{$List.Add($_.Result)}
		return $List
	}

	static Invoke([PSTaskRunner]$PSTaskRunner) {		
		while($PSTaskRunner.PSTasks.Count -gt 0) {
			$PSTask = $null
			try {
				$PSTaskRunner.PSTasks.TryDequeue([ref]$PSTask)
			}
			catch {
				[System.Threading.Thread]::Sleep(100)
			}
			if ($null -ne $PSTask) {
				$PSTaskRunner.PSTasksRunning.Enqueue($PSTask)
				
				try {
					[PSTaskRunner]::Invoke($PSTaskRunner, $PSTask)
				}
				catch {
					Throw $_.Exception.Message
				}
				finally {
					$PSTaskRunner.PSTasksRunning.TryDequeue([ref]$PSTask)
					$PSTaskRunner.PSTasksHistory.Enqueue($PSTask)
				}
			}
		}
	}
    
	static [PSTask] Invoke([PSTaskRunner]$PSTaskRunner, [PSTask]$PSTask) {
		# Create Powershell From PSTask and RunspacePool
		$PowerShell = [PSTaskRunner]::CreatePowerShell($PSTask, $PSTaskRunner.RunspacePool)

		# Create a Task from Powershell
		$PSTask.Task = [PSTaskRunner]::CreateTaskFromAsync($Powershell)
		
		Write-Verbose "PSTask $($PSTask.Id) Executing on TaskId $($PSTask.Task.Id)"
        
        return $PSTask
	}
    
	Invoke([PSTask]$PSTask) {
		# Create Powershell From PSTask and RunspacePool
		$PowerShell = [PSTaskRunner]::CreatePowerShell($PSTask, $this.RunspacePool)

		# Create a Task from Powershell
		$PSTask.Task = [PSTaskRunner]::CreateTaskFromAsync($Powershell)
	}
	
	static Start([PSTaskRunner]$PSTaskRunner) {
		[PSTaskRunner]::Invoke($PSTaskRunner)
		[PSTaskRunner]::WaitAll($PSTaskRunner)
	}
	static Start([PSTaskRunner]$PSTaskRunner, [PSTask]$PSTask) {
		[PSTaskRunner]::Invoke($PSTaskRunner, $PSTask)
		[PSTaskRunner]::WaitAll($PSTaskRunner)
	}
	
	static Stop([PSTaskRunner]$PSTaskRunner) {
		throw 'Not Implemented'
	}

	static Add([PSTaskRunner]$PSTaskRunner, [PSTask]$PSTask) {
		throw 'Not Implemented'
	}

	static WaitAny([PSTaskRunner]$PSTaskRunner) {
		[Task]::WaitAny($PSTaskRunner.PSTasks.ToArray().Task)
	}

	static WaitAll([PSTaskRunner]$PSTaskRunner) {
        [Task]::WaitAll($PSTaskRunner.PSTasks.ToArray().Task)
   }
    
	static Delay([int] $MillisecondsDelay) {
		[Task]::Delay($MillisecondsDelay)
	}
	
	static WhenAny([PSTaskRunner]$PSTaskRunner) {
		[Task]::WhenAny($PSTaskRunner.PSTasks.ToArray().Task)
	}
	
	static WhenAll([PSTaskRunner]$PSTaskRunner) {
		[Task]::WhenAll($PSTaskRunner.PSTasks.ToArray().Task)
	}
	
	static FromCanceled([CancellationToken]$CancellationToken) {
		[Task]::FromCanceled($CancellationToken)
	}
}
