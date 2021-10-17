 Function Check-ObjectPrimaryGroupID
 {
    <#  .SYNOPSIS
         Check for Primary Group ID of each object. 

        .PARAMETER Action
         Set to "remediate" if you want the script to cycle the PGID to the appropriate value.
         Set to "report"" if you want the script to only collect data and report it by mail or log.

        .PARAMETER SendMailReportTo
         Send a mail report to the specified mail address.

        .NOTES
         Version 01.00.000 by loic.veirman@mssec.fr
    #>
    Param(
        [parameter(mandatory=$true,Position=1)]
        [String]
        $Action,

        [Parameter(Position=2)]
        [String]
        $SendMailReportTo=$null
    )

    #.Checking User objects
    $BadObjects = Get-AdUser -Filter { PrimaryGroupID -ne 513 } -Properties PrimaryGroupID,displayName | Select sAMAccountName,UserPrincipalName,displayName

    if ($Action -eq "remediate")
    {
        
    }


 }