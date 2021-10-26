<#
    .SYNOPSIS
     Create a new daily schedule task with a gMSA account.

    .PARAMETER gMSAaccount
     Specify the account as domain\account$

    .PARAMETER cmdLine
     Secifiy the command to execute. If nothing specified, the default value is "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe".

    .PARAMETER cmdArgs 
     Specify the argument to add to the command line. Ex: -ExecutionPolicy Unrestricted -file sam.ps1

    .PARAMETER cmdWorkingDir
     The working directory from where the cmd line is executing itself.

    .NOTES
     Version 01.00.000
     Author: loic.veirman@mssec.fr

     https://www.windowscentral.com/how-create-scheduled-tasks-powershell-windows-10#:~:text=To%20create%20a%20scheduled%20task%20with%20PowerShell%20on,make%20sure%20to%20replace%20...%20More%20items...%20
     https://web.archive.org/web/20130627015803/http://blogs.technet.com/b/askpfeplat/archive/2012/12/17/windows-server-2012-group-managed-service-accounts.aspx
#>

Param(
    $gMSAaccount,
    $cmdLine="C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
    $cmdArgs,
    $cmdWorkingkDir,
    $TaskTime,
    $TaskFolder="MAD",
    $TaskName="SAM"
)

$action  = New-ScheduledTaskAction -Execute $cmdLine -Argument $cmdArgs -WorkingDirectory $cmdWorkingkDir
$Trigger = New-ScheduledTaskTrigger -Daily -At $TaskTime
$Account = New-ScheduledTaskPrincipal -UserId $gMSAaccount -LogonType Password

Register-ScheduledTask $TaskName -TaskPath $TaskFolder -Principal $Account -Action $action -Trigger $Trigger