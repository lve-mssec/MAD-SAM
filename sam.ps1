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
foreach ($mod in $LoadMods)
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
