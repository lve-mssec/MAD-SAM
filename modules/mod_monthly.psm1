Function Test-KerberosSecretLifespan
{
	<#  .SYNOPSIS 
		Function to ensure that the krbtgt account has its passowrd cycle on a regular basis.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.PARAMETER Lifespan
		specify the maximum lifespan allowed since the last password change.

		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Nov. 2021
	#>

	Param (
		[Parameter(mandatory=$true)]
		[int]
		$Lifespan
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "Kerberos Secret Lifespan Compliance (secret should be $Lifespan days old or less)"
															 
	#.Getting Data
	$PwdLastSet  = (Get-ADUser KRBTGT -Properties PasswordLastSet).PasswordLastSet
	$PwdLifespan = (Get-Date) - $PwdLastSet

	#.Checking result
	
	if ($PwdLifespan.Days -ge $Lifespan)
	{
		#.Has to be changed.
		$reportData += New-Object -TypeName psobject -Property @{sAMAccountName = 'KRBTGT' ; 'Compliant ?' = $False ; 'Password Last Set' = $PwdLastSet ; 'Password Age (days)' = $PwdLifespan.Days }
	}
	Else
	{
		#.Is under limits.
		$reportData += New-Object -TypeName psobject -Property @{sAMAccountName = 'KRBTGT' ; 'Compliant ?' = $True ; 'Password Last Set' = $PwdLastSet ; 'Password Age (days)' = $PwdLifespan.Days }
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","Compliant ?","Password Age (days)","Password Last Set")

	#.Output result
	Try { 
		$myReport | out-file .\Results\$htmlName -encoding UTF8 -Force
		$result = 0
	}
	Catch {
		$result = 2
	}

	#.leave function 
	return $result
}

Function Search-AssetsWithSidhistory
{
	<#  .SYNOPSIS 
		Function to crawl accounts against sidHistory persistence.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Nov. 2021
	#>

	Param (
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "Assets with a SIDhistory value defined (user, group, computer)"
															 
	#.Getting Data
	$UsrWithSidH = Get-ADUser     -Filter * -Properties sidHistory | Where-Object { $_.SIDHistory -ne $Null }
	$CprWithSidH = Get-ADComputer -Filter * -Properties sidHistory | Where-Object { $_.SIDHistory -ne $Null } 
	$GrpWithSidH = Get-ADGroup    -Filter * -Properties sidHistory | Where-Object { $_.SIDHistory -ne $Null }

	#.Checking result
	if ($UsrWithSidH)
	{
		foreach ($Data in $UsrWithSidH )
		{
			foreach ($SidH in $Data.SIDhistory)
			{
				$reportData += New-Object -TypeName psobject -Property @{ sAMAccountName = $Data.sAMAccountName ; ObjectClass = $Data.ObjectClass ; Enabled = $Data.Enabled ; 'SIDHistory data' = $SidH }
			}
		}
	}
	if ($CprWithSidH)
	{
		foreach ($Data in $CprWithSidH )
		{
			foreach ($SidH in $Data.SIDhistory)
			{
				$reportData += New-Object -TypeName psobject -Property @{ sAMAccountName = $Data.sAMAccountName ; ObjectClass = $Data.ObjectClass ; Enabled = $Data.Enabled ; 'SIDHistory data' = $SidH }
			}
		}
	}
	if ($GrpWithSidH)
	{
		foreach ($Data in $GrpWithSidH )
		{
			foreach ($SidH in $Data.SIDhistory)
			{
				$reportData += New-Object -TypeName psobject -Property @{ sAMAccountName = $Data.sAMAccountName ; ObjectClass = $Data.ObjectClass ; Enabled = $Data.Enabled ; 'SIDHistory data' = $SidH }
			}
		}
	}

	#.Managing no data issue
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psobject -Property @{ sAMAccountName = "No asset found" ; ObjectClass = $null ; Enabled = $null ; 'SIDHistory data' = $null }
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","ObjectClass","Enabled","SIDHistory data")

	#.Output result
	Try { 
		$myReport | out-file .\Results\$htmlName -encoding UTF8 -Force
		$result = 0
	}
	Catch {
		$result = 2
	}

	#.leave function 
	return $result
}

Function Export-ComputerNotPresent
{
	<#  .SYNOPSIS 
		Function to list all computer objects not logged in during a certain amount of time.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.PARAMETER Lifespan
		Specify the maximum lifespan allowed since the last logon.

		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Nov. 2021
	#>

	Param (
		[Parameter(mandatory=$true)]
		[int]
		$Lifespan
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "Active computer objects not logged in since $Lifespan days"
															 
	#.Getting Data
	$StaleCptr = Get-ADComputer -Filter { Enabled -eq $true } -Properties LAstLogonTimestamp | Where-Object { [DateTime]::FromFileTime($_.LastLogonTimestamp) -lt (Get-Date).AddDays(-$lifespan)}

	foreach ($Object in $StaleCptr)
	{
		$reportData += New-Object -TypeName psobject -Property @{ sAMAccountName = $Object.sAMAccountName ; 'Last logged in' = [datetime]::FromFileTime($Object.LastLogonTimestamp) ; 'Inactivity period (in days)' = ((Get-Date) - [DateTime]::FromFileTime($Object.LastLogonTimestamp)).Days }
	}

	#.Managing no data issue
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psobject -Property @{ sAMAccountName = "No asset found" ; 'Last logged in' = $null ; 'Inactivity Period (in days)' = $null }
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","Last logged in","Inactivity Period (in days)")

	#.Output result
	Try { 
		$myReport | out-file .\Results\$htmlName -encoding UTF8 -Force
		$result = 0
	}
	Catch {
		$result = 2
	}

	#.leave function 
	return $result
}

Function Search-ComputerWithLegacyOS
{
	<#  .SYNOPSIS 
		Function to list all computer objects declared with a legacy OS.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Nov. 2021
	#>

	Param (
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "Computer assets with a legacy OS defined"
															 
	#.Getting Data
	$LegacyCptr = Get-ADComputer -Filter * -Properties OperatingSystem,OperatingSystemVersion 

	#.Search for computer legacy OS
	$Before2k08 = $LegacyCptr | Where-Object { [int]$_.OperatingSystemVersion.split('.')[0] -lt 6 }
	$Before2k12 = $LegacyCptr | Where-Object { [int]$_.OperatingSystemVersion.split('.')[0] -eq 6 -and [int]$_.OperatingSystemVersion.split('.')[1] -le 1 }

	foreach ($Object in $Before2k08)
	{
		$reportData += New-Object -TypeName psobject -Property @{ sAMAccountName = $Object.sAMAccountName ; 'Operating System' = $Object.OperatingSystem ; 'OS Version' = $Object.OperatingSystemNumber ; Enabled = $Object.Enabled }
	}

	foreach ($Object in $Before2k12)
	{
		$reportData += New-Object -TypeName psobject -Property @{ sAMAccountName = $Object.sAMAccountName ; 'Operating System' = $Object.OperatingSystem ; 'OS Version' = $Object.OperatingSystemNumber ; Enabled = $Object.Enabled }
	}

	#.Managing no data issue
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psobject -Property @{ sAMAccountName = "No asset found" ; 'Operating System' = $null ; 'OS Version' = $null ; Enabled = $null }
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","Operating System","OS Version","Enabled")

	#.Output result
	Try { 
		$myReport | out-file .\Results\$htmlName -encoding UTF8 -Force
		$result = 0
	}
	Catch {
		$result = 2
	}

	#.leave function 
	return $result
}

Function Export-ComputerWithNoPasswordChange
{
	<#  .SYNOPSIS 
		Function to list all computer objects with a recent activity but without password changed for at least 45 days.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Nov. 2021
	#>

	Param (
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "Monthly active computer objects with a password older than 45 days"
															 
	#.Getting Data
	$ActiveCptr = Get-ADComputer -Filter { Enabled -eq $true } -Properties LastLogonTimestamp,PasswordLastSet | Where-Object { [DateTime]::FromFileTime($_.LastLogonTimestamp) -ge (Get-Date).AddDays(-30)}

	foreach ($Object in $ActiveCptr)
	{
		if ($Object.PasswordLastSet -lt (Get-Date).AddDays(-45))
		{
			$reportData += New-Object -TypeName psobject -Property @{ sAMAccountName = $Object.sAMAccountName ; 'Password Last Set' = $Object.PasswordLastSet ; 'Days with no change' = ((Get-Date) - $Object.PasswordLastSet).Days }
		}
	}

	#.Managing no data issue
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psobject -Property @{ sAMAccountName = "No asset found" ; 'Passwor Last Set' = $null ; 'Days with no change' = $null }
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","Password Last Set","Days with no change")

	#.Output result
	Try { 
		$myReport | out-file .\Results\$htmlName -encoding UTF8 -Force
		$result = 0
	}
	Catch {
		$result = 2
	}

	#.leave function 
	return $result
}

Function Test-msDSmachineAccountQuota
{
	<#  .SYNOPSIS 
		Ensure ms-DS-machineAccountQuota is set to 0.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Nov. 2021
	#>

	Param (
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "Check against Attribute ms-DS-machineAccountQuota"
															 
	#.Getting Data
	$object = Get-ADObject -Identity ((Get-ADDomain).distinguishedname) -Properties ms-DS-MachineAccountQuota

	if ($object.'ms-DS-MachineAccountQuota' -ne 0)
	{
		$reportData += New-Object -TypeName psobject -Property @{ Attribute = "ms-DS-MachineAccountQuota" ; 'Test OK ?' = $False ; 'Current value' = $object.'ms-DS-MachineAccountQuota' }
	}

	#.Managing no data issue
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psobject -Property @{ Attribute = "ms-DS-MachineAccountQuota" ; 'Test OK ?' = $True ; 'Current value' = $object.'ms-DS-MachineAccountQuota' }
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("Attribute","Test OK ?","Current value")

	#.Output result
	Try { 
		$myReport | out-file .\Results\$htmlName -encoding UTF8 -Force
		$result = 0
	}
	Catch {
		$result = 2
	}

	#.leave function 
	return $result
}
