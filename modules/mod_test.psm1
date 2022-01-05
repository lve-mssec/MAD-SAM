<# FUNCTION TEST #>
Function TEST
{
    Param()
    $randomTime = 1,1,1,3,3,3,3,2,2,4,4,4,5,5 | Get-Random
    $randomRslt = 1,1,1,1,1,0,0,0,2,2,2,2,2,2 | Get-Random

    Start-Sleep -Seconds $randomTime

    #return $randomRslt
    return 0
}

Function TEST-GrantPrivilege
{
    Param(
        [parameter(mandatory=$true)]$GrpName
    )    
    $svcAccount = ([xml](Get-Content .\Configs\Configuration.xml)).Settings.AccountName
    Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 99 -Message ("Test-RunAs: service account is $svcAccount")

    try 
    {
        Add-ADGroupMember -identity $GrpName -Members $svcAccount
        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 99 -Message ("Test-RunAs: service account added to $GrpName")
    }
    Catch
    {
        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Error -EventId 99 -Message ("Test-RunAs: Failed to add service account to $GrpName")
    }
    
    return 0
}

Function TEST-RemovePrivilege
{
    Param(
        [parameter(mandatory=$true)]$GrpName
    )    
    $svcAccount = ([xml](Get-Content .\Configs\Configuration.xml)).Settings.AccountName
    Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 99 -Message ("Test-RunAs: service account is $svcAccount")

    try 
    {
        Remove-ADGroupMember -identity $GrpName -Members $svcAccount -confirm:$false
        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Information -EventId 99 -Message ("Test-RunAs: service account removed from $GrpName")
    }
    Catch
    {
        Write-EventLog -LogName Application -Source 'MAD_SAM' -EntryType Error -EventId 99 -Message ("Test-RunAs: Failed to remove service account from $GrpName")
    }
    
    return 0
}


Export-ModuleMember -Function *