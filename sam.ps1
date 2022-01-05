<#
    .SYNOPSIS
     SAM: System to Automate Maintenance

    .DESCRIPTION
     SAM is intended to perform scheduled tasks in order to maintain Active Directory as secure and operational as possible.

    .NOTES
     Version 01.00
     Author loic.veirman@mssec.fr
#>

Param()

###################################################################
## Script Block                                                  ##
## ------------                                                  ##
## Function called by the script block should return a psObject: ##
## ResultCode: 0 (success), 1 (warning), 2 (error), 3 (ignore)   ##
## ResultMesg: Message to be displayed on screen.                ##
## TaskExeLog: Message to be added at global log.                ##
##                                                               ##
## When calling the block, parameters should be passed through   ##
## an array (@()); the function will then deal the parameter by  ##
## itself.                                                       ##
###################################################################
$Block = {  
    param(   
        #-Name of the function to be executed
        [Parameter(Mandatory=$true,Position=0)]
        [String]
        $Command,
        #-Parameter set to be passed as argument to $command
        [Parameter(Mandatory=$true,Position=1)]
        $Parameters,
        #-Set the execution context in a specific path. 
        #-Needed to relocate the new pShell process at the same calling space to find modules, etc.
        [Parameter(Mandatory=$true,Position=2)]
        [String]
        $Location,
        #-Array of modules to be loaded for this function to run.
        [Parameter(Mandatory=$false,Position=3)]
        $mods
    )

    #-Relocating the new pShell session to the same location as the calling script.
    Push-Location $Location

    #-Checking OS to handle pShell 2.0w
    if ((Get-WMIObject win32_operatingsystem).name -like "*2008*")
    {
        $is2k8r2 = $true
    } 
    else 
    {
        $is2k8r2 = $false
    }

    #-Loading modules, if needed.
    Try
    { 
        #-Module loading...
        if ($is2k8r2)
        {
            $null = $mods | forEach-Object { Import-Module $_.fullName -DisableNameChecking }
        } 
        else 
        {
            $null = $mods | forEach-Object { Import-Module $_ -DisableNameChecking }
        }
    }
    Catch 
    { 
        #-No module to be loaded.
    }

    #-Run the function
    Try
    {
        #-Checking for multiple parameters and OS...
        #-More than 1 parameter but greater than 2008 R2
        if ($Parameters.count -gt 1 -and -not ($is2k8r2)) 
        {
            $RunData = . $Command @Parameters | Select-Object -ExcludeProperty PSComputerName,RunspaceId,PSShowComputerName
        } 
        
        #-More than 1 parameter and is 2008 R2
        if ($Parameters.count -gt 1 -and $is2k8r2) 
        {
            #-pShell 2.0 is not able to translate the multiple useParameters inputs from the xml file.
            # We rewrite the parmaters in a more compliant way.
            $tmpParam = @()
            for ($i = 0 ; $i -lt $Parameters.count ; $i++) 
            {
                $tmpParam += $Parameters[$i]
            }
            $RunData = . $Command @TmpParam | Select-Object -ExcludeProperty PSComputerName,RunspaceId,PSShowComputerName
        }
        
        #-1 parameter or less
        if ($Parameters.count -le 1) 
        {
            $RunData = . $Command $Parameters | Select-Object -ExcludeProperty PSComputerName,RunspaceId,PSShowComputerName
        }
    }
    Catch 
    {
        $RunData = New-Object -TypeName psobject -Property @{ResultCode = 9 ; ResultMesg = "Error launching the function $command" ; TaskExeLog = "Error"}
    }

    #.Return the result
    $RunData
}
#####################
## End ScriptBlock ##
#####################
# - Script Variables
$ScriptLocation = Get-Location  
$scriptModules  = (Get-ChildItem .\Modules -Filter "*.psm1").FullName

# - Prepare logging requierment
$knownSources = Get-ChildItem -Path "HKLM:\System\CurrentControlSet\services\eventlog\Application\" -Name
if (-not ($knownSources -contains "MAD_SAM"))
{
    #.Create a new Source
    Try {
        New-EventLog -LogName 'Application' -Source 'MAD_SAM' -ErrorAction Stop
    } Catch {
        Exit 999
    }
}
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 1 -Message ("SAM is starting its scheduled run")

# - Import module files. If a module fail to load, the script will over (code 998)
$LoadMods = Get-ChildItem .\Modules -Filter { isPsContainer -eq $false }
forEach ($mod in $LoadMods)
{
    Try { 
        Import-Module $mod -ErrorAction Stop
        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 1 -Message ("Module " + $mod.Name + " loaded successfully")
    } Catch {
        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Error -EventId 998 -Message ("Failes to load Module " + $mod.Name + "! Script over!")
        Exit 998
    }
}
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 1 -Message ("All modules loaded successfully")

# - Fork from here!
# - Loading the XML tasks data file
$xmlSchedule = [xml](Get-Content .\Configs\Schedules.xml)
$xmlConfig   = [xml](Get-Content .\Configs\Configuration.xml)

# - Define run specific case : Week in current month, Day, Hour, Minute.
# - WeekDay will be returned as a numrical value (1=Monday, 7=Sunday)
$runWeek = (Get-WmiObject Win32_LocalTime).weekinmonth
$runWday = (get-date).DayOfWeek.value__ 
$runHour = (Get-Date).Hour
$runMin  = (Get-Date).Minute

$log  = "Run Data:"
$log += "`n  Week number in month: $runWeek"
$log += "`n  Day number in week: $runWday"
$log += "`n  Start time: " + $runHour +":" + $runMin

# - Hour Segment (hourSgt) is used to identify in xhich hour quarter we are set.
if ($runMin -lt 15) { $hourSgt = 1 }
if ($runMin -ge 15 -and $runMin -lt 30) { $hourSgt = 2 }
if ($runMin -ge 30 -and $runMin -lt 45) { $hourSgt = 3 }
if ($runMin -ge 45) { $hourSgt = 4 }

$log += "`n  Hour Quartered number: $hourSgt"
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 1 -Message $log

# - Grab actions to perform
$bTasks = $xmlSchedule.tasks.Task | Where-Object { $_.Frequency -eq "always"  } | Where-Object {      $_.runAt.always  -eq 'Begin'  }
$eTasks = $xmlSchedule.tasks.Task | Where-Object { $_.Frequency -eq "always"  } | Where-Object {      $_.runAt.always  -eq 'End'    }
$qTasks = $xmlSchedule.tasks.Task | Where-Object { $_.Frequency -eq "Hourly"  } | Where-Object {      $_.runAt.Quarter -eq $hourSgt }

$dTasks = $xmlSchedule.tasks.Task | Where-Object { $_.Frequency -eq "daily"   } | Where-Object {      $_.runAt.Quarter -eq $hourSgt `
                                                                                                 -and $_.runAt.hour    -eq $runHour }

$wTasks = $xmlSchedule.tasks.Task | Where-Object { $_.Frequency -eq "weekly"  } | Where-Object {      $_.runAt.Quarter -eq $hourSgt `
                                                                                                 -and $_.runAt.hour    -eq $runHour `
                                                                                                 -and $_.RunAt.Day     -eq $runWday }

$mTasks = $xmlSchedule.tasks.Task | Where-Object { $_.Frequency -eq "Monthly" } | Where-Object {      $_.runAt.Quarter -eq $hourSgt `
                                                                                                 -and $_.runAt.hour    -eq $runHour `
                                                                                                 -and $_.RunAt.Day     -eq $runWday `
                                                                                                 -and $_.runAt.Week    -eq $runWeek }
# - Create Job Sequence hrml result variable
$htmlReport = @("<header><h1>MAD SAM (Maintening AD - System for Automatic Maintenance)</h1><p>Loic VEIRMAN (MSSEC) - Version 01.00</p></header>")

# - Run "always at begining" tasks
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 4 -Message "Running Prerequesite tasks"
forEach ($task in $bTasks)
{
    if ($task.Enabled -eq "yes")
    {
        #.Logging
        $Log  =   "Starting new script sequence " + $task.Name
        $Log += "`n`nFrequency: " + $task.Frequency
        $Log += "`nEnabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 2 -Message $log
        
        #.Run job
        $job = Start-Job -ScriptBlock $Block -Name CurrentJob -ArgumentList $task.Script.Name,$task.Script.Parameter,$ScriptLocation,$scriptModules

        #.Waiting for script to end its run before running another one.
        While ((Get-Job $job.Id).State -eq "Running")
        {
            Start-Sleep -Milliseconds 100
        }

        #.Grab result code, then kill the job
        $result = Receive-Job $job.Id
        Remove-Job $job.ID

        #.Define output message
        Switch ($result)
        {
            $Task.ResultCode.success { $resMsg = $Task.ResultCode.successMessage ; $EntryType = "SuccessAudit" }
            $Task.ResultCode.warning { $resMsg = $Task.ResultCode.warningMessage ; $EntryType = "Warning" }
            $Task.ResultCode.error   { $resMsg = $Task.ResultCode.errorMessage   ; $EntryType = "Error" }
        }

        #.To troubleshot
        if (-not($EntryType)) 
        {
            $EntryType = "information"
            $resMsg    = "Failed to retrieve task result data!"
        }

        #.Logging result
        $Log  =   "Script " + $task.Name + " ended." 
        $Log += "`n`nResult message: " + $resMsg

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType $EntryType -EventId 2 -Message $log

        #.Adding result to final html file
        $htmlTarget = [String]$task.Script.Name + ".html"
        if (Test-Path .\Results\$htmlTarget)
        {
            $htmlReport += Get-Content .\Results\$htmlTarget
        }
    }
    Else 
    {
        #.Skip this one.
        $Log  =   "Skipping script: " + $task.Name
        $Log += "`n      Frequency: " + $task.Frequency
        $Log += "`n        Enabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 3 -Message $log
    }
}

# - Run quartely tasks
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 4 -Message "Hour's Quarter Tasks starting"
forEach ($task  in $qTasks) 
{
    if ($task.Enabled -eq "yes")
    {
        #.Logging
        $Log  =   "Starting new script sequence " + $task.Name
        $Log += "`n`nFrequency: " + $task.Frequency
        $Log += "`nEnabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 2 -Message $log
        
        #.Run job
        $job = Start-Job -ScriptBlock $Block -Name CurrentJob -ArgumentList $task.Script.Name,$task.Script.Parameter,$ScriptLocation,$scriptModules

        #.Waiting for script to end its run before running another one.
        While ((Get-Job $job.Id).State -eq "Running")
        {
            Start-Sleep -Milliseconds 100
        }

        #.Grab result code, then kill the job
        $result = Receive-Job $job.Id
        Remove-Job $job.ID

        #.Define output message
        Switch ($result)
        {
            $Task.ResultCode.success { $resMsg = $Task.ResultCode.successMessage ; $EntryType = "SuccessAudit" }
            $Task.ResultCode.warning { $resMsg = $Task.ResultCode.warningMessage ; $EntryType = "Warning" }
            $Task.ResultCode.error   { $resMsg = $Task.ResultCode.errorMessage   ; $EntryType = "Error" }
        }

        #.Logging result
        $Log  =   "Script " + $task.Name + " ended." 
        $Log += "`n`nResult message: " + $resMsg

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType $EntryType -EventId 2 -Message $log

        #.Adding result to final html file
        $htmlTarget = [String]$task.Script.Name + ".html"
        if (Test-Path .\Results\$htmlTarget)
        {
            $htmlReport += Get-Content .\Results\$htmlTarget
        }
    }
    Else 
    {
        #.Skip this one.
        $Log  =   "Skipping script: " + $task.Name
        $Log += "`n      Frequency: " + $task.Frequency
        $Log += "`n        Enabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 3 -Message $log
    }
}

# - Run Daily tasks
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 4 -Message "Daily Tasks starting"
forEach ($task  in $dTasks) 
{
    if ($task.Enabled -eq "yes")
    {
        #.Logging
        $Log  =   "Starting new script sequence " + $task.Name
        $Log += "`n`nFrequency: " + $task.Frequency
        $Log += "`nEnabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 2 -Message $log
        
        #.Run job
        $job = Start-Job -ScriptBlock $Block -Name CurrentJob -ArgumentList $task.Script.Name,$task.Script.Parameter,$ScriptLocation,$scriptModules

        #.Waiting for script to end its run before running another one.
        While ((Get-Job $job.Id).State -eq "Running")
        {
            Start-Sleep -Milliseconds 100
        }

        #.Grab result code, then kill the job
        $result = Receive-Job $job.Id
        Remove-Job $job.ID

        #.Define output message
        Switch ($result)
        {
            $Task.ResultCode.success { $resMsg = $Task.ResultCode.successMessage ; $EntryType = "SuccessAudit" }
            $Task.ResultCode.warning { $resMsg = $Task.ResultCode.warningMessage ; $EntryType = "Warning" }
            $Task.ResultCode.error   { $resMsg = $Task.ResultCode.errorMessage   ; $EntryType = "Error" }
        }

        #.Logging result
        $Log  =   "Script " + $task.Name + " ended." 
        $Log += "`n`nResult message: " + $resMsg

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType $EntryType -EventId 2 -Message $log
        
        #.Adding result to final html file
        $htmlTarget = [String]$task.Script.Name + ".html"
        if (Test-Path .\Results\$htmlTarget)
        {
            $htmlReport += Get-Content .\Results\$htmlTarget
        }
    }
    Else 
    {
        #.Skip this one.
        $Log  =   "Skipping script: " + $task.Name
        $Log += "`n      Frequency: " + $task.Frequency
        $Log += "`n        Enabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 3 -Message $log
    }
}

# - Run weekly tasks
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 4 -Message "Weekly Tasks starting"
forEach ($task  in $wTasks) 
{
    if ($task.Enabled -eq "yes")
    {
        #.Logging
        $Log  =   "Starting new script sequence " + $task.Name
        $Log += "`n`nFrequency: " + $task.Frequency
        $Log += "`nEnabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 2 -Message $log
        
        #.Run job
        $job = Start-Job -ScriptBlock $Block -Name CurrentJob -ArgumentList $task.Script.Name,$task.Script.Parameter,$ScriptLocation,$scriptModules

        #.Waiting for script to end its run before running another one.
        While ((Get-Job $job.Id).State -eq "Running")
        {
            Start-Sleep -Milliseconds 100
        }

        #.Grab result code, then kill the job
        $result = Receive-Job $job.Id
        Remove-Job $job.ID

        #.Define output message
        Switch ($result)
        {
            $Task.ResultCode.success { $resMsg = $Task.ResultCode.successMessage ; $EntryType = "SuccessAudit" }
            $Task.ResultCode.warning { $resMsg = $Task.ResultCode.warningMessage ; $EntryType = "Warning" }
            $Task.ResultCode.error   { $resMsg = $Task.ResultCode.errorMessage   ; $EntryType = "Error" }
        }

        #.Logging result
        $Log  =   "Script " + $task.Name + " ended." 
        $Log += "`n`nResult message: " + $resMsg

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType $EntryType -EventId 2 -Message $log
        
        #.Adding result to final html file
        $htmlTarget = [String]$task.Script.Name + ".html"
        if (Test-Path .\Results\$htmlTarget)
        {
            $htmlReport += Get-Content .\Results\$htmlTarget
        }
    }
    Else 
    {
        #.Skip this one.
        $Log  =   "Skipping script: " + $task.Name
        $Log += "`n      Frequency: " + $task.Frequency
        $Log += "`n        Enabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 3 -Message $log
    }
}

# - Run monthly tasks
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 4 -Message "Monthly Tasks starting"
forEach ($task  in $mTasks) 
{
    if ($task.Enabled -eq "yes")
    {
        #.Logging
        $Log  =   "Starting new script sequence " + $task.Name
        $Log += "`n`nFrequency: " + $task.Frequency
        $Log += "`nEnabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 2 -Message $log
        
        #.Run job
        $job = Start-Job -ScriptBlock $Block -Name CurrentJob -ArgumentList $task.Script.Name,$task.Script.Parameter,$ScriptLocation,$scriptModules

        #.Waiting for script to end its run before running another one.
        While ((Get-Job $job.Id).State -eq "Running")
        {
            Start-Sleep -Milliseconds 100
        }

        #.Grab result code, then kill the job
        $result = Receive-Job $job.Id
        Remove-Job $job.ID

        #.Define output message
        Switch ($result)
        {
            $Task.ResultCode.success { $resMsg = $Task.ResultCode.successMessage ; $EntryType = "SuccessAudit" }
            $Task.ResultCode.warning { $resMsg = $Task.ResultCode.warningMessage ; $EntryType = "Warning" }
            $Task.ResultCode.error   { $resMsg = $Task.ResultCode.errorMessage   ; $EntryType = "Error" }
        }

        #.Logging result
        $Log  =   "Script " + $task.Name + " ended." 
        $Log += "`n`nResult message: " + $resMsg

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType $EntryType -EventId 2 -Message $log
        
        #.Adding result to final html file
        $htmlTarget = [String]$task.Script.Name + ".html"
        if (Test-Path .\Results\$htmlTarget)
        {
            $htmlReport += Get-Content .\Results\$htmlTarget
        }
    }
    Else 
    {
        #.Skip this one.
        $Log  =   "Skipping script: " + $task.Name
        $Log += "`n      Frequency: " + $task.Frequency
        $Log += "`n        Enabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 3 -Message $log
    }
    Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 5 -Message "All run done"
}

# - Run "always at end" tasks
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 4 -Message "Running cleanup tasks"
start-Sleep -s 1
forEach ($task in $eTasks)
{
    if ($task.Enabled -eq "yes")
    {
        #.Logging
        $Log  =   "Starting new script sequence " + $task.Name
        $Log += "`n`nFrequency: " + $task.Frequency
        $Log += "`nEnabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 2 -Message $log
        
        #.Run job
        $job = Start-Job -ScriptBlock $Block -Name CurrentJob -ArgumentList $task.Script.Name,$task.Script.Parameter,$ScriptLocation,$scriptModules

        #.Waiting for script to end its run before running another one.
        While ((Get-Job $job.Id).State -eq "Running")
        {
            Start-Sleep -Milliseconds 100
        }

        #.Grab result code, then kill the job
        $result = Receive-Job $job.Id
        Remove-Job $job.ID

        #.Define output message
        Switch ($result)
        {
            $Task.ResultCode.success { $resMsg = $Task.ResultCode.successMessage ; $EntryType = "SuccessAudit" }
            $Task.ResultCode.warning { $resMsg = $Task.ResultCode.warningMessage ; $EntryType = "Warning" }
            $Task.ResultCode.error   { $resMsg = $Task.ResultCode.errorMessage   ; $EntryType = "Error" }
        }

        #.Logging result
        $Log  =   "Script " + $task.Name + " ended." 
        $Log += "`n`nResult message: " + $resMsg

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType $EntryType -EventId 2 -Message $log
        
        #.Adding result to final html file
        $htmlTarget = [String]$task.Script.Name + ".html"
        if (Test-Path .\Results\$htmlTarget)
        {
            $htmlReport += Get-Content .\Results\$htmlTarget
        }
    }
    Else 
    {
        #.Skip this one.
        $Log  =   "Skipping script: " + $task.Name
        $Log += "`n      Frequency: " + $task.Frequency
        $Log += "`n        Enabled: " + $task.Enabled

        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 3 -Message $log
    }
}
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 0 -Message "Script's over"

# - Export to HTML file final report
$ReportName = "Rapport du " + (Get-Date -Format "dd MMM yyyy - hh\hmm") + ".html"
$htmlReport | Out-File .\Results\$ReportName -Encoding utf8

# - Send mail report
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 1 -Message ("Sending mail report")

$password = ConvertTo-SecureString ([string]($xmlConfig.settings.SmtpPassword)) -AsPlainText -Force
$smtpCred = New-Object System.Management.Automation.PSCredential ($xmlConfig.settings.SmtpLogin, $password)

if ($xmlConfig.settings.SmtpLogin -eq 'no')
{
    $UseSsl   = $false
}
Else
{
    $UseSsl   = $True
}

$recipients = @()

Foreach ($recipient in $xmlConfig.settings.SmtpRecipient)
{
    $recipients += $recipient
}

Send-MailMessage -Body "Bonjour,`nVeuillez trouver ci-joint le résultat de l'exécution de la tâche planifiée." `
                 -Attachments   .\Results\$ReportName `
                 -From $xmlConfig.settings.SmtpSender `
                 -SmtpServer $xmlConfig.Settings.SmtpServer `
                 -Subject "MAD SAM - Rapport d'Execution" `
                 -Port $xmlConfig.settings.SmtpPort `
                 -Credential $smtpCred `
                 -To $Recipients

# - Remove module files. 
forEach ($mod in $LoadMods)
{
    Try { 
        Remove-Module ($mod.name -replace ".psm1","") -ErrorAction Stop
        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 1 -Message ("Module " + $mod.Name + " unloaded successfully")
    } Catch {
        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Error -EventId 998 -Message ("Failes to unload Module " + $mod.Name + "!")
        Exit 998
    }
}
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 1 -Message ("All modules unloaded successfully")
Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 1 -Message ("Schedule Task's over.")