<# FUNCTION TEST #>
Function TEST{
    Param()
    $randomTime = 1,1,1,3,3,3,3,2,2,4,4,4,5,5 | Get-Random
    $randomRslt = 1,1,1,1,1,0,0,0,2,2,2,2,2,2 | Get-Random

    Start-Sleep -Seconds $randomTime

    return $randomRslt
}

Export-ModuleMember -Function *