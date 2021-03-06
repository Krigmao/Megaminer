Add-Type -Path .\Includes\OpenCL\*.cs



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function set_Nvidia_Clocks ([int]$PowerLimitPercent, [string]$Devices) {

    $device = $Devices -split ','
    $device |ForEach-Object {

        $xpr = ".\bin\nvidia-smi.exe -i " + $_ + " --query-gpu=power.default_limit --format=csv,noheader"
        $PowerDefaultLimit = [int]((invoke-expression $xpr) -replace 'W', '')

        #powerlimit change must run in admin mode
        $newProcess = New-Object System.Diagnostics.ProcessStartInfo ".\bin\nvidia-smi.exe"
        $newProcess.Verb = "runas"
        #$newProcess.UseShellExecute = $false
        $newProcess.Arguments = "-i " + $_ + " -pl " + [Math]::Floor([int]($PowerDefaultLimit -replace ' W', '') * ($PowerLimitPercent / 100))
        [System.Diagnostics.Process]::Start($newProcess) | out-null
    }
    Remove-Variable newprocess
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function set_Nvidia_Powerlimit ([int]$PowerLimitPercent, [string]$Devices) {

    $device = $Devices -split ','
    $device | ForEach-Object {

        $xpr = ".\bin\nvidia-smi.exe -i " + $_ + " --query-gpu=power.default_limit --format=csv,noheader"
        $PowerDefaultLimit = [int]((invoke-expression $xpr) -replace 'W', '')


        #powerlimit change must run in admin mode
        $newProcess = New-Object System.Diagnostics.ProcessStartInfo ".\bin\nvidia-smi.exe"
        $newProcess.Verb = "runas"
        #$newProcess.UseShellExecute = $false
        $newProcess.Arguments = "-i " + $_ + " -pl " + [Math]::Floor([int]($PowerDefaultLimit -replace ' W', '') * ($PowerLimitPercent / 100))
        [System.Diagnostics.Process]::Start($newProcess) | out-null
    }
    Remove-Variable newprocess
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_ComputerStats {
    [cmdletbinding()]
    $avg = Get-CimInstance win32_processor | Measure-Object -property LoadPercentage -Average | ForEach-Object {$_.Average}
    $mem = Get-CimInstance win32_operatingsystem | ForEach-Object {"{0:N2}" -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) * 100) / $_.TotalVisibleMemorySize)}
    $memV = Get-CimInstance win32_operatingsystem | ForEach-Object {"{0:N2}" -f ((($_.TotalVirtualMemorySize - $_.FreeVirtualMemory) * 100) / $_.TotalVirtualMemorySize)}
    $free = Get-CimInstance Win32_Volume -Filter "DriveLetter = 'C:'" | ForEach-Object {"{0:N2}" -f (($_.FreeSpace / $_.Capacity) * 100)}
    $nprocs = (Get-Process).count
    $Conns = (Get-NetTCPConnection).count

    "AverageCpu = $avg % | MemoryUsage = $mem % | VirtualMemoryUsage = $memV % | PercentCFree = $free % | Processes = $nprocs | Connections = $Conns"
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
function ErrorsTolog ($LogFile) {

    for ($i = 0; $i -lt $error.count; $i++) {
        $Msg = "###### ERROR ##### " + [string]($error[$i]) + ' ' + $error[$i].ScriptStackTrace
        Writelog $msg $LogFile

    }
    $error.clear()
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function replace_foreach_gpu {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFileArguments,
        [Parameter(Mandatory = $false)]
        [string]$Gpus
    )



    #search string to replace

    $ConfigFileArguments = $ConfigFileArguments -replace [Environment]::NewLine, "#NL#" #replace carriage return for Select-string search (only search in each line)

    $Match = $ConfigFileArguments | Select-String -Pattern "#FOR_EACH_GPU#.*?#END_FOR_EACH_GPU#"
    if ($Match -ne $null) {

        $Match.Matches | ForEach-Object {
            $Base = $_.value -replace "#FOR_EACH_GPU#", "" -replace "#END_FOR_EACH_GPU#", ""
            $Final = ""
            $Gpus -split ',' | ForEach-Object {$Final += ($base -replace "#GPUID#", $_)}
            $ConfigFileArguments = $ConfigFileArguments.Substring(0, $_.index) + $final + $ConfigFileArguments.Substring($_.index + $_.Length, $ConfigFileArguments.Length - ($_.index + $_.Length))
        }
    }


    $Match = $ConfigFileArguments | Select-String -Pattern "#REMOVE_LAST_CHARACTER#"
    if ($Match -ne $null) {
        $Match.Matches | ForEach-Object {
            $ConfigFileArguments = $ConfigFileArguments.Substring(0, $_.index - 1) + $ConfigFileArguments.Substring($_.index + $_.Length, $ConfigFileArguments.Length - ($_.index + $_.Length))
        }
    }

    $ConfigFileArguments = $ConfigFileArguments -replace "#NL#", [Environment]::NewLine #replace carriage return for Select-string search (only search in each line)
    $ConfigFileArguments
}
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function get_next_free_port {
    param(
        [Parameter(Mandatory = $true)]
        [int]$LastUsedPort
    )


    if ($LastUsedPort -lt 2000) {$FreePort = 2001} else {$FreePort = $LastUsedPort + 1} #not allow use of <2000 ports
    while (Query_TCPPort -Server 127.0.0.1 -Port $FreePort -timeout 100) {$FreePort = $LastUsedPort + 1}
    $FreePort
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Query_TCPPort {
    param([string]$Server, [int]$Port, [int]$Timeout)

    $Connection = New-Object System.Net.Sockets.TCPClient

    try {
        $Connection.SendTimeout = $Timeout
        $Connection.ReceiveTimeout = $Timeout
        $Connection.Connect($Server, $Port) | out-Null
        $Connection.Close
        $Connection.Dispose
        return $true #port is occupied
    } catch {
        $Error.Remove($error[$Error.Count - 1])
        return $false  #port is free
    }
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Kill_Process {
    param(
        [Parameter(Mandatory = $true)]
        $Process
    )

    $sw = [Diagnostics.Stopwatch]::new()
    try {
        $Process.CloseMainWindow() | Out-Null
        $sw.Start()
        do {
            if ($sw.Elapsed.TotalSeconds -gt 1) {
                Stop-Process -InputObject $Process -Force
            }
            if (!$Process.HasExited) {
                Start-Sleep -Milliseconds 1
            }
        } while (!$Process.HasExited)
    } finally {
        $sw.Stop()
        if (!$Process.HasExited) {
            Stop-Process -InputObject $Process -Force
        }
    }
    Remove-Variable sw
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function get_devices_information ($Types) {
    [cmdletbinding()]

    $Devices = @()

    #NVIDIA
    $NVPlatform = [OpenCl.Platform]::GetPlatformIDs() | Where-Object vendor -like "*NVIDIA*"
    if ($NVPlatform -ne $null) {
        $GpuId = 0
        Invoke-Expression ".\bin\nvidia-smi.exe --query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,pstate,clocks.current.graphics,clocks.current.memory,power.max_limit,power.default_limit --format=csv,noheader" | ForEach-Object {
            $SMIresultSplit = $_ -split (",")
            if ($SMIresultSplit.count -gt 10) {
                #less is error or no NVIDIA gpu present

                $Group = ($Types | Where-Object type -eq 'NVIDIA' | Where-Object GpusArray -contains $GpuId).groupname

                $Card = [pscustomObject]@{
                    Type               = 'NVIDIA'
                    Id                 = $GpuId
                    Group              = $Group
                    Name               = $SMIresultSplit[0]
                    Utilization        = if ($SMIresultSplit[1] -like "*Supported*") {100} else {[int]($SMIresultSplit[1] -replace '%', '')} #If we dont have real Utilization, at least make the watchdog happy
                    Utilization_Memory = if ($SMIresultSplit[2] -like "*Supported*") {$null} else {[int]($SMIresultSplit[2] -replace '%', '')}
                    Temperature        = if ($SMIresultSplit[3] -like "*Supported*") {$null} else {[int]($SMIresultSplit[3] -replace '%', '')}
                    Power_Draw         = if ($SMIresultSplit[4] -like "*Supported*") {$null} else {[int]($SMIresultSplit[4] -replace 'W', '')}
                    Power_Limit        = if ($SMIresultSplit[5] -like "*Supported*") {$null} else {[int]($SMIresultSplit[5] -replace 'W', '')}
                    Pstate             = $SMIresultSplit[7]
                    FanSpeed           = if ($SMIresultSplit[6] -like "*Supported*") {$null} else {[int]($SMIresultSplit[6] -replace '%', '')}
                    Clock              = if ($SMIresultSplit[8] -like "*Supported*") {$null} else {[int]($SMIresultSplit[8] -replace 'Mhz', '')}
                    ClockMem           = if ($SMIresultSplit[9] -like "*Supported*") {$null} else {[int]($SMIresultSplit[9] -replace 'Mhz', '')}
                    Power_MaxLimit     = if ($SMIresultSplit[10] -like "*Supported*") {$null} else { [int]($SMIresultSplit[10] -replace 'W', '')}
                    Power_DefaultLimit = if ($SMIresultSplit[11] -like "*Supported*") {$null} else {[int]($SMIresultSplit[11] -replace 'W', '')}
                }
                if ($Card.Power_DefaultLimit -gt 0) { $Card | Add-Member Power_limit_percent ([math]::Floor(($Card.power_limit * 100) / $Card.Power_DefaultLimit))}
                $Devices += $Card
                $GpuId++
            }
        }
    }


    #AMD
    $AMDPlatform = [OpenCl.Platform]::GetPlatformIDs() | Where-Object vendor -like "*Advanced Micro Devices*"
    if ($AMDPlatform -ne $null) {
        #ADL
        $GpuId = 0
        $AdlResult = invoke-expression ".\bin\OverdriveN.exe" | Where-Object {$_ -notlike "*&???" -and $_ -ne "ADL2_OverdriveN_Capabilities_Get is failed"}
        $AmdCardsTDP = Get-Content .\Includes\amd-cards-tdp.json | ConvertFrom-Json

        if ($AdlResult -ne $null) {
            $AdlResult | ForEach-Object {

                $AdlResultSplit = $_ -split (",")
                $Group = ($Types | Where-Object type -eq 'AMD' | Where-Object GpusArray -contains $GpuId).groupname

                $Devices += [pscustomObject]@{
                    Type                = 'AMD'
                    Id                  = $GpuId
                    Group               = $Group
                    AdapterId           = [int]$AdlResultSplit[0]
                    FanSpeed            = [int][int]([int]$AdlResultSplit[1] / [int]$AdlResultSplit[2] * 100)
                    Clock               = [int]([int]($AdlResultSplit[3] / 100))
                    ClockMem            = [int]([int]($AdlResultSplit[4] / 100))
                    Utilization         = [int]$AdlResultSplit[5]
                    Temperature         = [int]$AdlResultSplit[6] / 1000
                    Power_Limit_Percent = 100 + [int]$AdlResultSplit[7]
                    Power_Draw          = $AmdCardsTDP.$($AdlResultSplit[8].Trim()) * ((100 + [double]$AdlResultSplit[7]) / 100) * ([double]$AdlResultSplit[5] / 100)
                    Name                = $AdlResultSplit[8].Trim()
                    UDID                = $AdlResultSplit[9].Trim()
                }
                $GpuId++
            }
        } else {
            # For older drivers
            $AdlResult = invoke-expression ".\bin\adli.exe -n"
            $AdlResult | ForEach-Object {

                $AdlResultSplit = $_ -split (",")
                $GpuId = [int]$AdlResultSplit[0]
                $Group = ($Types | Where-Object type -eq 'AMD' | Where-Object GpusArray -contains $GpuId ).groupname

                $Devices += [pscustomObject]@{
                    Type                = 'AMD'
                    Id                  = $GpuId
                    Group               = $Group
                    FanSpeed            = [int]$AdlResultSplit[3]
                    Temperature         = [int]$AdlResultSplit[2]
                    Utilization         = 100 #If we dont have real Utilization, at least make the watchdog happy
                    Power_Limit_Percent = 100
                    Power_Draw          = $AmdCardsTDP.$($AdlResultSplit[1].Trim())
                    Name                = $AdlResultSplit[1].Trim()
                }
            }
        }
        Clear-Variable AmdCardsTDP
    }
    $CpuResult = Get-CimInstance Win32_Processor
    $CpuTDP = Get-Content ".\Includes\cpu-tdp.json" | ConvertFrom-Json
    # Language independent version of Get-Counter '\Processor(_Total)\% Processor Time'
    $CpuLoad = (Get-Counter -Counter '\238(_Total)\6').CounterSamples.CookedValue / 100
    $CpuResult | ForEach-Object {
        $Devices += [pscustomObject]@{
            Type        = 'CPU'
            Id          = $_.DeviceID
            Group       = "CPU"
            Clock       = $_.MaxClockSpeed
            Utilization = $_.LoadPercentage
            CacheL3     = $_.L3CacheSize
            Cores       = $_.NumberOfCores
            Threads     = $_.NumberOfLogicalProcessors
            Power_Draw  = [int]($CpuTDP.($_.Name) * $CpuLoad)
            Name        = $_.Name
        }
    }
    Clear-Variable CpuTDP

    $Devices
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function print_devices_information ($Devices) {

    foreach ($T in @('NVIDIA', 'AMD', 'Intel')) {
        $Devices | Where-Object Type -eq $T | Format-Table -Wrap  (
            @{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
            @{Label = "Group"; Expression = {$_.Group}; Align = 'right'},
            @{Label = "Name"; Expression = {$_.Name}},
            @{Label = "Load"; Expression = {[string]$_.Utilization + "%"}; Align = 'right'},
            @{Label = "Mem"; Expression = {[string]$_.Utilization_Memory + "%"}; Align = 'right'},
            @{Label = "Temp"; Expression = {$_.Temperature}; Align = 'right'},
            @{Label = "Fan"; Expression = {[string]$_.FanSpeed + "%"}; Align = 'right'},
            @{Label = "Power"; Expression = {[string]$_.Power_Draw + "W/" + [string]$_.Power_Limit + "W"}; Align = 'right'},
            @{Label = "PowLmt"; Expression = {[string]$_.Power_Limit_Percent + '%'}; Align = 'right'},
            @{Label = "Pstate"; Expression = {$_.pstate}; Align = 'right'},
            @{Label = "Clock"; Expression = {[string]$_.Clock + "Mhz"}; Align = 'right'},
            @{Label = "ClkMem"; Expression = {[string]$_.ClockMem + "Mhz"}; Align = 'right'}
        ) -groupby Type | Out-Host
    }

    $Devices | Where-Object Type -eq 'CPU' | Format-Table -Wrap  (
        @{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
        @{Label = "Group"; Expression = {$_.Group}; Align = 'right'},
        @{Label = "Name"; Expression = {$_.Name}},
        @{Label = "Cores"; Expression = {$_.Cores}},
        @{Label = "Threads"; Expression = {$_.Threads}},
        @{Label = "CacheL3"; Expression = {[string]$_.CacheL3 + "kb"}; Align = 'right'},
        @{Label = "Clock"; Expression = {[string]$_.Clock + "Mhz"}; Align = 'right'},
        @{Label = "Load"; Expression = {[string]$_.Utilization + "%"}; Align = 'right'},
        @{Label = "Power*"; Expression = {[string]$_.Power_Draw + "W"}; Align = 'right'}
    )  -groupby Type | Out-Host
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function get_comma_separated_string {
    param(
        [Parameter(Mandatory = $true)]
        [int]$start,
        [Parameter(Mandatory = $true)]
        [int]$lenght
    )

    $result = $null


    for ($i = $start; $i - $start -lt $lenght; $i++) {
        if ($result -ne $null) {$result += ","}
        $result = $result + [string]$i
    }
    $result
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

Function Get_Mining_Types () {
    param(
        [Parameter(Mandatory = $false)]
        [array]$Filter = $null
    )


    if ($Filter -eq $null) {$Filter = @()} # to allow comparation after

    $Types = @()
    $OCLDevices = @()

    $Types0 = get_config_variable "GpuGroups" | ConvertFrom-Json

    $OCLPlatforms = [OpenCl.Platform]::GetPlatformIDs()
    for ($i = 0; $i -lt $OCLPlatforms.length; $i++) {$OCLDevices += ([OpenCl.Device]::GetDeviceIDs($OCLPlatforms[$i], "ALL"))}

    if ($Types0 -eq $null) {
        #Autodetection on, must add types manually
        $Types0 = @()

        $NumberNvidiaGPU = ($OCLDevices | Where-Object Vendor -like '*NVIDIA*' | Measure-Object).count
        if ($NumberNvidiaGPU -gt 0) {
            $Types0 += [pscustomobject] @{
                GroupName   = "NVIDIA"
                Type        = "NVIDIA"
                Gpus        = (get_comma_separated_string 0 $NumberNvidiaGPU)
                Powerlimits = "0"
            }
        }

        $NumberAmdGPU = ($OCLDevices | Where-Object Vendor -like '*Advanced Micro Devices*' | Measure-Object).count
        if ($NumberAmdGPU -gt 0) {
            $Types0 += [pscustomobject] @{
                GroupName   = "AMD"
                Type        = "AMD"
                Gpus        = (get_comma_separated_string 0 $NumberAmdGPU)
                Powerlimits = "0"
            }
        }

        # $NumberIntelGPU = ($OCLDevices | Where-Object Vendor -like '*Intel*' | Measure-Object).count
        # if ($NumberIntelGPU -gt 0) {
        #     $Types0 += [pscustomobject] @{
        #         GroupName   = "Intel"
        #         Type        = "Intel"
        #         Gpus        = (get_comma_separated_string 0 $NumberIntelGPU)
        #         Powerlimits = "0"
        #     }
        # }
    }

    #if cpu mining is enabled add a new group
    if (
        ((get_config_variable "CPUMINING") -eq 'ENABLED' -and ($Filter | Measure-Object).count -eq 0) -or
        ((compare-object "CPU" $Filter -IncludeEqual -ExcludeDifferent | Measure-Object).count -gt 0)
    ) {
        $Types0 += [pscustomobject]@{
            GroupName   = "CPU"
            Type        = "CPU"
            Gpus        = $null
            PowerLimits = "0"
        }
    }


    $c = 0
    $Types0 | ForEach-Object {
        if (
            ((compare-object $_.Groupname $Filter -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0) -or
            (($Filter | Measure-Object).count -eq 0)
        ) {
            $_ | Add-Member Id $c
            $c = $c + 1

            $_ | Add-Member GpusClayMode ($_.gpus -replace '10', 'A' -replace '11', 'B' -replace '12', 'C' -replace '13', 'D' -replace '14', 'E' -replace '15', 'F' -replace '16', 'G' -replace ',', '')
            $_ | Add-Member GpusETHMode ($_.gpus -replace ',', ' ')
            $_ | Add-Member GpusNsgMode ("-d " + $_.gpus -replace ',', ' -d ')
            $_ | Add-Member GpuPlatform (Get_Gpu_Platform $_.Type)
            $_ | Add-Member GpusArray ($_.gpus -split ",")
            $Pl = @()
            ($_.PowerLimits -split ',') | ForEach-Object {$Pl += [int]$_}
            $_.PowerLimits = $Pl | Sort-Object -Descending

            if ($_.PowerLimits.Count -eq 0 -or $_.Type -in @('AMD', 'Intel')) {$_.PowerLimits = [array](0) }

            $_ | Add-Member Algorithms ((get_config_variable ("Algorithms_" + $_.Type)) -split ',')
            $Types += $_
        }
    }
    $Types #return
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


Function WriteLog ($Message, $LogFile, $SendToScreen) {

    if (![string]::IsNullOrWhitespace($message)) {

        $M = [string](get-date) + "...... " + $Message
        $LogFile.WriteLine($M)

        if ($SendToScreen) { $Message | Write-Host -ForegroundColor Green }
    }
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


Function Timed_ReadKb {
    param(
        [Parameter(Mandatory = $true)]
        [int]$secondsToWait,
        [Parameter(Mandatory = $true)]
        [array]$ValidKeys

    )

    $Loopstart = Get-Date
    $KeyPressed = $null

    while ((NEW-TIMESPAN $Loopstart (Get-Date)).Seconds -le $SecondsToWait -and $ValidKeys -notcontains $KeyPressed) {
        if ($host.ui.RawUi.KeyAvailable) {
            $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
            $KeyPressed = $Key.character
            while ($Host.UI.RawUI.KeyAvailable) {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush

        }
        start-sleep -m 30
    }
    $KeyPressed
}





#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Gpu_Platform {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Type
    )
    switch ($Type) {
        "AMD" { $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.')) }
        "Intel" { $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Intel')) }
        Default { 0 }
    }

}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Clear_Screen_Zone {
    param(
        [Parameter(Mandatory = $true)]
        [int]$startY,
        [Parameter(Mandatory = $true)]
        [int]$endY
    )

    $BlankLine = " " * $Host.UI.RawUI.WindowSize.Width

    Set_ConsolePosition 0 $start

    for ($i = $startY; $i -le $endY; $i++) {
        $BlankLine | write-host
    }
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Invoke_TcpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost",
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [Parameter(Mandatory = $true)]
        [String]$Request,
        [Parameter(Mandatory = $true)]
        [Int]$Timeout = 10 #seconds
    )

    try {
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        $Writer = New-Object System.IO.StreamWriter $Stream
        $Reader = New-Object System.IO.StreamReader $Stream
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true

        $Writer.WriteLine($Request)
        $Response = $Reader.ReadLine()
    } catch { $Error.Remove($error[$Error.Count - 1])}
    finally {
        if ($Reader) {$Reader.Close()}
        if ($Writer) {$Writer.Close()}
        if ($Stream) {$Stream.Close()}
        if ($Client) {$Client.Close()}
    }
    $response
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Invoke_httpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost",
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [Parameter(Mandatory = $false)]
        [String]$Request,
        [Parameter(Mandatory = $true)]
        [Int]$Timeout = 10 #seconds
    )

    try {
        $response = Invoke-WebRequest "http://$($Server):$Port$Request" -UseBasicParsing -TimeoutSec $timeout
    } catch {$Error.Remove($error[$Error.Count - 1])}

    $response
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Live_HashRate {
    param(
        [Parameter(Mandatory = $true)]
        [String]$API,
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $false)]
        [Object]$Parameters = @{}

    )

    $Server = "localhost"

    try {
        switch ($API) {

            "Dtsm" {
                $Request = Invoke_TcpRequest $server $port "empty" 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request | ConvertFrom-Json | Select-Object  -ExpandProperty result
                    $HashRate = [Double](($Data.sol_ps) | Measure-Object -Sum).Sum
                }
            }

            "xgminer" {
                $Message = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress
                $Request = Invoke_TcpRequest $server $port $Message 5

                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request.Substring($Request.IndexOf("{"), $Request.LastIndexOf("}") - $Request.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json

                    $HashRate = if ($Data.SUMMARY.HS_5s -ne $null) {[Double]$Data.SUMMARY.HS_5s * [math]::Pow(1000, 0)}
                    elseif ($Data.SUMMARY.KHS_5s -ne $null) {[Double]$Data.SUMMARY.KHS_5s * [math]::Pow(1000, 1)}
                    elseif ($Data.SUMMARY.MHS_5s -ne $null) {[Double]$Data.SUMMARY.MHS_5s * [math]::Pow(1000, 2)}
                    elseif ($Data.SUMMARY.GHS_5s -ne $null) {[Double]$Data.SUMMARY.GHS_5s * [math]::Pow(1000, 3)}
                    elseif ($Data.SUMMARY.THS_5s -ne $null) {[Double]$Data.SUMMARY.THS_5s * [math]::Pow(1000, 4)}
                    elseif ($Data.SUMMARY.PHS_5s -ne $null) {[Double]$Data.SUMMARY.PHS_5s * [math]::Pow(1000, 5)}

                    if ($HashRate -eq $null) {
                        $HashRate = if ($Data.SUMMARY.HS_av -ne $null) {[Double]$Data.SUMMARY.HS_av * [math]::Pow(1000, 0)}
                        elseif ($Data.SUMMARY.KHS_av -ne $null) {[Double]$Data.SUMMARY.KHS_av * [math]::Pow(1000, 1)}
                        elseif ($Data.SUMMARY.MHS_av -ne $null) {[Double]$Data.SUMMARY.MHS_av * [math]::Pow(1000, 2)}
                        elseif ($Data.SUMMARY.GHS_av -ne $null) {[Double]$Data.SUMMARY.GHS_av * [math]::Pow(1000, 3)}
                        elseif ($Data.SUMMARY.THS_av -ne $null) {[Double]$Data.SUMMARY.THS_av * [math]::Pow(1000, 4)}
                        elseif ($Data.SUMMARY.PHS_av -ne $null) {[Double]$Data.SUMMARY.PHS_av * [math]::Pow(1000, 5)}
                    }
                }
            }

            "palgin" {
                $Request = Invoke_TcpRequest $server $port "summary" 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request -split ";"
                    $HashRate = [double]($Data[5] -split '=')[1] * 1000
                }
            }

            "ccminer" {
                $Request = Invoke_TcpRequest $server $port "summary" 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request -split ";" | ConvertFrom-StringData
                    $HashRate = if ([double]$Data.'HS' -gt 0) {[double]$Data.'HS'}
                    elseif ([double]$Data.'KHS' -gt 0) {[double]$Data.'KHS' * [math]::Pow(1000, 1)}
                    elseif ([double]$Data.'MHS' -gt 0) {[double]$Data.'MHS' * [math]::Pow(1000, 2)}
                    elseif ([double]$Data.'GHS' -gt 0) {[double]$Data.'GHS' * [math]::Pow(1000, 3)}
                    elseif ([double]$Data.'THS' -gt 0) {[double]$Data.'THS' * [math]::Pow(1000, 4)}
                    elseif ([double]$Data.'PHS' -gt 0) {[double]$Data.'PHS' * [math]::Pow(1000, 5)}
                }
            }

            "nicehashequihash" {
                $Request = Invoke_TcpRequest $server $port "status" 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = $Data.result.speed_hps
                    if ($HashRate -eq $null) {$HashRate = $Data.result.speed_sps}
                }
            }

            "excavator" {
                $Message = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
                $Request = Invoke_TcpRequest $server $port $message 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = ($Request | ConvertFrom-Json).Algorithms
                    $HashRate = [Double](($Data.workers.speed) | Measure-Object -Sum).Sum
                }
            }

            "ewbf" {
                $Message = @{id = 1; method = "getstat"} | ConvertTo-Json -Compress
                $Request = Invoke_TcpRequest $server $port $message 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [Double](($Data.result.speed_sps) | Measure-Object -Sum).Sum
                }
            }

            "Claymore" {
                $Message = '{"id":0,"jsonrpc":"2.0","method":"miner_getstat1"}'
                $Request = Invoke_TcpRequest -Server $Server -Port $Port -Request $Message -Timeout 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request | ConvertFrom-Json
                    $Miner = $Data.result[0]
                    switch -wildcard ($Miner) {
                        "* - ETH" {$Multiplier = 1000} #Ethash
                        "* - NS" {$Multiplier = 1000} #NeoScrypt
                        Default {$Multiplier = 1}
                    }
                    $HashRate = [double]$Data.result[2].Split(";")[0] * $Multiplier
                    $HashRate_Dual = [double]$Data.result[4].Split(";")[0] * $Multiplier
                }
            }

            "prospector" {
                $Request = Invoke_httpRequest $Server 42000 "/api/v0/hashrates" 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [Double]($Data.rate | Measure-Object -Sum).sum
                }
            }

            "wrapper" {
                $HashRate = ""
                $wrpath = ".\Wrapper_$Port.txt"
                $HashRate = if (test-path -path $wrpath ) {
                    Get-Content  $wrpath
                    $HashRate = ($HashRate -split ',')[0]
                    $HashRate = ($HashRate -split '.')[0]
                } else {$hashrate = 0}
            }

            "castXMR" {
                $Request = Invoke_httpRequest $Server $Port "" 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [Double]($Data.devices.hash_rate | Measure-Object -Sum).Sum / 1000
                }
            }

            "XMrig" {
                $Request = Invoke_httpRequest $Server $Port "/api.json" 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [Double]$Data.hashrate.total[0]
                }
            }

            "Bminer" {
                $Request = Invoke_httpRequest $Server $Port "/api/status" 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request.content | ConvertFrom-Json
                    $HashRate = 0
                    $Data.miners | Get-Member -MemberType NoteProperty | ForEach-Object {
                        $HashRate += $Data.miners.($_.name).solver.solution_rate
                    }
                }
            }

            "optiminer" {
                $Request = Invoke_httpRequest $Server $Port "" 5
                if (![string]::IsNullOrEmpty($Request)) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [Double]($Data.solution_rate.Total."60s" | Measure-Object -Sum).sum
                    if ($HashRate -eq 0) { $HashRate = [Double]($Data.solution_rate.Total."5s" | Measure-Object -Sum).sum }
                }
            }
        } #end switch

        $HashRates = @()
        $HashRates += [double]$HashRate
        $HashRates += [double]$HashRate_Dual

        $HashRates
    } catch {}
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function ConvertTo_Hash {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Hash
    )


    $Return = switch ([math]::truncate([math]::log($Hash, [math]::Pow(1000, 1)))) {

        "-Infinity" {"0 h"}
        0 {"{0:n1} h" -f ($Hash / [math]::Pow(1000, 0))}
        1 {"{0:n1} kh" -f ($Hash / [math]::Pow(1000, 1))}
        2 {"{0:n1} mh" -f ($Hash / [math]::Pow(1000, 2))}
        3 {"{0:n1} gh" -f ($Hash / [math]::Pow(1000, 3))}
        4 {"{0:n1} th" -f ($Hash / [math]::Pow(1000, 4))}
        Default {"{0:n1} ph" -f ($Hash / [math]::Pow(1000, 5))}
    }
    $Return
}




#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Start_SubProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath,
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "",
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "",
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)] <# UselessGuru #>
        [String]$MinerWindowStyle = "Minimized", <# UselessGuru #>
        [Parameter(Mandatory = $false)] <# UselessGuru #>
        [String]$UseAlternateMinerLauncher = $true <# UselessGuru #>
    )

    $PriorityNames = [PSCustomObject]@{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}

    if ($UseAlternateMinerLauncher) {

        $ShowWindow = [PSCustomObject]@{"Normal" = "SW_SHOW"; "Maximized" = "SW_SHOWMAXIMIZE"; "Minimized" = "SW_SHOWMINNOACTIVE"}

        $Job = Start-Job `
            -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)');. .\Includes\CreateProcess.ps1")) `
            -ArgumentList $PID, $FilePath, $ArgumentList, $ShowWindow.$MinerWindowStyle, $PriorityNames.$Priority, $WorkingDirectory {
            param($ControllerProcessID, $FilePath, $ArgumentList, $ShowWindow, $Priority, $WorkingDirectory)

            . .\Includes\CreateProcess.ps1
            $ControllerProcess = Get-Process -Id $ControllerProcessID
            if ($ControllerProcess -eq $null) {return}

            $Process = Invoke-CreateProcess `
                -Binary $FilePath `
                -Arguments $ArgumentList `
                -CreationFlags CREATE_NEW_CONSOLE `
                -ShowWindow $ShowWindow `
                -StartF STARTF_USESHOWWINDOW `
                -Priority $Priority `
                -WorkingDirectory $WorkingDirectory
            if ($Process -eq $null) {
                [PSCustomObject]@{ProcessId = $null}
                return
            }

            [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}

            $ControllerProcess.Handle | Out-Null
            $Process.Handle | Out-Null

            do {if ($ControllerProcess.WaitForExit(1000)) {$Process.CloseMainWindow() | Out-Null}}
            while ($Process.HasExited -eq $false)
        }
    } else {
        $Job = Start-Job -ArgumentList $PID, $FilePath, $ArgumentList, $WorkingDirectory, $MinerWindowStyle {
            param($ControllerProcessID, $FilePath, $ArgumentList, $WorkingDirectory, $MinerWindowStyle)

            $ControllerProcess = Get-Process -Id $ControllerProcessID
            if ($ControllerProcess -eq $null) {return}

            $ProcessParam = @{}
            $ProcessParam.Add("FilePath", $FilePath)
            $ProcessParam.Add("WindowStyle", $MinerWindowStyle)
            if ($ArgumentList -ne "") {$ProcessParam.Add("ArgumentList", $ArgumentList)}
            if ($WorkingDirectory -ne "") {$ProcessParam.Add("WorkingDirectory", $WorkingDirectory)}
            $Process = Start-Process @ProcessParam -PassThru
            if ($Process -eq $null) {
                [PSCustomObject]@{ProcessId = $null}
                return
            }

            [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}

            $ControllerProcess.Handle | Out-Null
            $Process.Handle | Out-Null

            do {if ($ControllerProcess.WaitForExit(1000)) {$Process.CloseMainWindow() | Out-Null}}
            while ($Process.HasExited -eq $false)

        }
    }

    do {Start-Sleep 1; $JobOutput = Receive-Job $Job}
    while ($JobOutput -eq $null)

    $Process = Get-Process | Where-Object Id -EQ $JobOutput.ProcessId
    $Process.Handle | Out-Null
    $Process

    if ($Process) {$Process.PriorityClass = $PriorityNames.$Priority}
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Expand_WebRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri,
        [Parameter(Mandatory = $true)]
        [String]$Path,
        [Parameter(Mandatory = $false)]
        [String]$SHA256
    )


    $DestinationFolder = $PSScriptRoot + $Path.Substring(1)
    $FileName = ([IO.FileInfo](Split-Path $Uri -Leaf)).name
    $FilePath = $PSScriptRoot + '\' + $Filename


    if (Test-Path $FileName) {Remove-Item $FileName}
    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing

    if (Test-Path $FileName) {
        if (![string]::IsNullOrEmpty($SHA256)) {
            $FileHash = (Get-FileHash -Path $FileName -Algorithm SHA256).Hash
            if ($FileHash -ne $SHA256) {
                "File hash doesn't match. Skipping miner." + $FileHash + " " + $SHA256 | Write-Host
                Remove-Item $FileName
                Return
            }
        }

        $Command = 'x "' + $FilePath + '" -o"' + $DestinationFolder + '" -y -spe'
        Start-Process ".\bin\7z.exe" $Command -Wait
        Remove-Item $FileName
    }
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Get_Pools {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Querymode = 'core',
        [Parameter(Mandatory = $false)]
        [array]$PoolsFilterList = $null,
        #[array]$PoolsFilterList='Mining_pool_hub',
        [Parameter(Mandatory = $false)]
        [array]$CoinFilterList,
        #[array]$CoinFilterList = ('GroestlCoin','Feathercoin','zclassic'),
        [Parameter(Mandatory = $false)]
        [string]$Location = $null,
        #[string]$Location='EU'
        [Parameter(Mandatory = $false)]
        [array]$AlgoFilterList,
        [Parameter(Mandatory = $false)]
        [pscustomobject]$Info
    )
    #in detail mode returns a line for each pool/algo/coin combination, in info mode returns a line for pool

    if ($location -eq 'GB') {$location = 'EU'}

    $PoolsFolderContent = Get-ChildItem ($PSScriptRoot + '\pools') | Where-Object {$PoolsFilterList.Count -eq 0 -or (Compare-Object $PoolsFilterList $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}

    $ChildItems = @()

    if ($info -eq $null) { $Info = [pscustomobject]@{}
    }

    if (($info | Get-Member -MemberType NoteProperty | Where-Object name -eq location) -eq $null) {$info | Add-Member Location $Location}

    $info | Add-Member SharedFile [string]$null

    $PoolsFolderContent | ForEach-Object {

        $Basename = $_.BaseName
        $SharedFile = $PSScriptRoot + "\" + $Basename + [string](Get-Random -minimum 0 -maximum 9999999) + ".tmp"
        $info.SharedFile = $SharedFile

        if (Test-Path $SharedFile) {Remove-Item $SharedFile}
        &$_.FullName -Querymode $Querymode -Info $Info
        if (Test-Path $SharedFile) {
            $Content = Get-Content $SharedFile | ConvertFrom-Json
            Remove-Item $SharedFile
        } else { $Content = $null }
        $Content | ForEach-Object {$ChildItems += [PSCustomObject]@{Name = $Basename; Content = $_}}
    }

    $AllPools = $ChildItems | ForEach-Object {if ($_.content -ne $null) {$_.Content | Add-Member @{Name = $_.Name} -PassThru}}


    $AllPools | Add-Member LocationPriority 9999

    #Apply filters
    $AllPools2 = @()
    if ($Querymode -eq "core" -or $Querymode -eq "menu" ) {
        foreach ($Pool in $AllPools) {
            #must have wallet
            if ($Pool.User -ne $null) {

                #must be in algo filter list or no list
                if ($AlgoFilterList -ne $null) {$Algofilter = Compare-Object $AlgoFilterList $Pool.Algorithm -IncludeEqual -ExcludeDifferent}
                if ($AlgoFilterList.count -eq 0 -or $Algofilter -ne $null) {

                    #must be in coin filter list or no list
                    if ($CoinFilterList -ne $null) {$Coinfilter = Compare-Object $CoinFilterList $Pool.info -IncludeEqual -ExcludeDifferent}
                    if ($CoinFilterList.count -eq 0 -or $Coinfilter -ne $null) {
                        if ($Pool.Location -eq $Location) {$Pool.LocationPriority = 1}
                        elseif ($Pool.Location -in @('EU', 'EUROPE') -and $Location -eq 'US') {$Pool.LocationPriority = 2}
                        elseif ($Pool.Location -eq 'US' -and $Location -in @('EU', 'EUROPE')) {$Pool.LocationPriority = 2}
                        $AllPools2 += $Pool
                    }
                }
            }
        }
        #Insert by priority of location
        if (![string]::IsNullOrEmpty($Location)) {
            $Return = @()
            $AllPools2 | Sort-Object Info, Algorithm, LocationPriority | ForEach-Object {
                $Ex = $Return | Where-Object Info -eq $_.Info | Where-Object Algorithm -eq $_.Algorithm | Where-Object PoolName -eq $_.PoolName
                if ($Ex.count -eq 0) {$Return += $_}
            }
        } else { $Return = $AllPools2 }
    } else { $Return = $AllPools }


    Remove-variable AllPools
    Remove-variable AllPools2

    $Return
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function get_config {


    $content = [pscustomobject]@{}
    Get-Content config.txt | Where-Object {$_ -like "@@*"} | ForEach-Object {
        $content | Add-Member (($_ -split '=')[0] -replace '@@', '') (($_ -split '=')[1])
    }
    $content
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


Function get_config_variable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VarName
    )

    $Var = [string]$null
    $content = @()

    $SearchPattern = "@@" + $VarName + "=*"

    Get-Content config.txt | Where-Object {$_ -like $SearchPattern} | ForEach-Object {$content += ($_ -split '=')[1]}
    if (($content | Measure-Object).count -gt 1) {$var = $content} else {$var = [string]$content[0]}
    if ($Var -ne $null) {$Var.Trim()}
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Best_Hashrate_Algo {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm
    )


    $Pattern = "*_" + $Algorithm + "_*_HashRate.txt"

    $Besthashrate = 0

    Get-ChildItem ($PSScriptRoot + "\Stats") -Filter $Pattern | ForEach-Object {
        $Content = ($_ | Get-Content | ConvertFrom-Json )
        $Hrs = 0
        if ($Content -ne $null) {$Hrs = $($Content | Where-Object TimeSinceStartInterval -gt 60 | Measure-Object -property Speed -average).Average}

        if ($Hrs -gt $Besthashrate) {
            $Besthashrate = $Hrs
            $Miner = ($_.pschildname -split '_')[0]
        }
        $Return = [pscustomobject]@{
            Hashrate = $Besthashrate
            Miner    = $Miner
        }
    }
    $Return
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Algo_Divisor {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algo
    )

    $Divisor = 1000000000

    switch (get_algo_unified_name $Algo) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "keccakc" {$Divisor *= 1000}
        "skein" {$Divisor *= 1000}
        "yescrypt" {$Divisor /= 1000}
    }
    $Divisor
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function set_ConsolePosition ([int]$x, [int]$y) {
    # Get current cursor position and store away
    $position = $host.ui.rawui.cursorposition
    # Store new X Co-ordinate away
    $position.x = $x
    $position.y = $y
    # Place modified location back to $HOST
    $host.ui.rawui.cursorposition = $position
    remove-variable position
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_ConsolePosition ([ref]$x, [ref]$y) {

    $position = $host.UI.RawUI.CursorPosition
    $x.value = $position.x
    $y.value = $position.y
    remove-variable position
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
function Print_Horizontal_line ([string]$Title) {

    $Width = $Host.UI.RawUI.WindowSize.Width
    if ([string]::IsNullOrEmpty($Title)) {$str = "-" * $Width}
    else {
        $str = ("-" * ($Width / 2 - ($Title.Length / 2) - 4)) + "  " + $Title + "  "
        $str += "-" * ($Width - $str.Length)
    }
    $str | Out-Host
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function set_WindowSize ([int]$Width, [int]$Height) {
    #zero not change this axis


    $pshost = Get-Host
    $RawUI = $pshost.UI.RawUI

    #Buffer must be always greater than windows size

    $BSize = $Host.UI.RawUI.BufferSize
    if ($Width -ne 0 -and $Width -gt $BSize.Width) {$BSize.Width = $Width}
    if ($Height -ne 0 -and $Height -gt $BSize.Height) {$BSize.Width = $Height}

    $Host.UI.RawUI.BufferSize = $BSize


    $WSize = $Host.UI.RawUI.WindowSize
    if ($Width -ne 0) {$WSize.Width = $Width}
    if ($Height -ne 0) {$WSize.Height = $Height}

    $Host.UI.RawUI.WindowSize = $WSize
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function get_algo_unified_name ([string]$Algo) {

    if (![string]::IsNullOrEmpty($Algo)) {
        $Algos = Get-Content -Path ".\Includes\algorithms.json" | ConvertFrom-Json
        if ($Algos.($Algo.Trim()) -ne $null) { $Algos.($Algo.Trim()) }
        else { $Algo.Trim() }
    }
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function  get_coin_unified_name ([string]$Coin) {

    if (![string]::IsNullOrEmpty($Coin)) {
        switch -wildcard ($Coin.Trim()) {
            "Auroracoin-*" { "Auroracoin" }
            "Dgb-*" { "Digibyte" }
            "Digibyte-*" { "Digibyte" }
            "Ethereum-Classic" { "EthereumClassic" }
            "Myriad-*" { "Myriad" }
            "Myriadcoin-*" { "Myriad" }
            "Verge-*" { "Verge" }
            "Bitcoin-Gold" { "BitcoinGold" }
            "Bitcoin-Cash" { "BitcoinCash" }
            Default { $Coin.Trim() }
        }
    }
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Get_Hashrates {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel
    )


    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}
    $Pattern = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_HashRate.txt"

    if (test-path -path $pattern) {
        $Content = (Get-Content -path $pattern)
        try {$Content = $Content | ConvertFrom-Json} catch {
            #if error from convert from json delete file
            writelog ("Corrupted file $Pattern, deleting") $LogFile $true
            remove-item -path $pattern
        }
    }

    if ($Content -eq $null) {$Content = @()}
    $content
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Set_Hashrates {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Value,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit
    )


    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}

    $Path = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_HashRate.txt"

    $Value | Convertto-Json | Set-Content  -Path $Path
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Stats {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel
    )

    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}
    $Pattern = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_stats.txt"

    if (Test-Path -path $pattern) {
        $Content = (Get-Content -path $pattern)
        try {$Content = $Content | ConvertFrom-Json} catch {
            #if error from convert from json delete file
            writelog ("Corrupted file $Pattern, deleting") $LogFile $true
            Remove-Item -path $pattern
        }
    }
    $content
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Set_Stats {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$value,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit
    )


    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}

    $Path = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_stats.txt"

    $Value | Convertto-Json | Set-Content -Path $Path
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Start_Downloader {
    param(
        [Parameter(Mandatory = $true)]
        [String]$URI,
        [Parameter(Mandatory = $true)]
        [String]$ExtractionPath,
        [Parameter(Mandatory = $true)]
        [String]$Path,
        [Parameter(Mandatory = $false)]
        [String]$SHA256
    )

    if (-not (Test-Path $Path)) {
        try {


            if ($URI -and (Split-Path $URI -Leaf) -eq (Split-Path $Path -Leaf)) {
                New-Item (Split-Path $Path) -ItemType "Directory" | Out-Null
                Invoke-WebRequest $URI -OutFile $Path -UseBasicParsing -ErrorAction Stop
            } else {
                Clear-Host
                $Message = "Downloading....$($URI)"
                Write-Host -BackgroundColor green -ForegroundColor Black  $Message
                Writelog $Message $LogFile
                Expand_WebRequest $URI $ExtractionPath -ErrorAction Stop
            }
        } catch {
            $Message = "Cannot download $URI"
            Write-Host -BackgroundColor Yellow -ForegroundColor Black $Message
            WriteLog $Message $LogFile

            if ($Path_Old) {
                if (Test-Path (Split-Path $Path_New)) {(Split-Path $Path_New) | Remove-Item -Recurse -Force}
                (Split-Path $Path_Old) | Copy-Item -Destination (Split-Path $Path_New) -Recurse -Force
            } else {
                $Message = "Cannot find $($Path) distributed at $($URI). "
                Write-Host -BackgroundColor Yellow -ForegroundColor Black $Message
                Writelog $Message $LogFile
            }
        }
    }
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Clear_Log {

    $Now = Get-Date
    $Days = "3"

    $TargetFolder = ".\Logs"
    $Extension = "*.txt"
    $LastWrite = $Now.AddDays( - $Days)

    $Files = Get-Childitem $TargetFolder -Include $Extension -Exclude "empty.txt" -Recurse | Where-Object {$_.LastWriteTime -le "$LastWrite"}

    $Files | ForEach-Object {Remove-Item $_.fullname}
    $TargetFolder = "."
    $Extension = "wrapper_*.txt"

    $Files = Get-Childitem $TargetFolder -Include $Extension -Recurse
    $Files |ForEach-Object {Remove-Item $_.fullname}
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function get_coin_symbol ([string]$Coin) {

    switch -wildcard  ($Coin) {
        "adzcoin" { "ADZ" }
        "auroracoin" { "AUR" }
        "bitcoincash" { "BCH" }
        "bitcoingold" { "BTG" }
        "bitcoin" { "BTC" }
        "dash" { "DASH" }
        "decred" { "DCR" }
        "digibyte" { "DGB" }
        "electroneum" { "ETN" }
        "ethereumclassic" { "ETC" }
        "ethereum" { "ETH" }
        "expanse" { "EXP" }
        "feathercoin" { "FTC" }
        "gamecredits" { "GAME" }
        "geocoin" { "GEO" }
        "globalboosty" { "BSTY" }
        "groestlcoin" { "GRS" }
        "litecoin" { "LTC" }
        "maxcoin" { "MAX" }
        "monacoin" { "MONA" }
        "monero" { "XMR" }
        "musicoin" { "MUSIC" }
        "myriad" { "XMY" }
        "pascal" { "PASC" }
        "polytimos" { "POLY" }
        "sexcoin" { "SXC" }
        "siacoin" { "SC" }
        "startcoin" { "START" }
        "verge" { "XVG" }
        "vertcoin" { "VTC" }
        "zcash" { "ZEC" }
        "zclassic" { "ZCL" }
        "zcoin" { "XZC" }
        "zencash" { "ZEN" }
        Default { $Coin }
    }
}
