Function Search-AccountWithBadPrimaryGroupID
{
	<#  .SYNOPSIS 
		Function to search for account with a bad primary group ID (I.E. not Domain Admins).
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Nov. 2021
	#>

	Param (
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	#$htmlName   = "$scriptName.html"
	$reportDatU = @()
	$reportDatC = @()
	$reportDatD = @()

	#.Function Data
	$FunctionDatU = "User Objects with bad Primary Group ID"
	$FunctionDatC = "Computer Objects with bad Primary Group ID"
	$FunctionDatD = "Domain Controller Objects with bad Primary Group ID"
															 
	#.Building Exception List
	$areDCs  = @()
	Get-ADDomainController | ForEach-Object { $dc= $_.Name ; $sam = [String](Get-ADComputer -Identity $dc).sAMAccountName ; $areDCs = Get-ADComputer $dc | select sAMAccountName }

	$GuestID = [String]((Get-ADDomain).DomainSID) + "-501"
	$isGuest = (Get-ADUser -Filter { SID -eq $GuestID }).sAMAccountName

	#.Grabbing User elements
	$collection = Get-ADUser -Filter { PrimaryGroupID -ne "513" } -Properties PrimaryGroupID | Where-Object { $_.sAMAccountName -notmatch $isGuest }

	#.Loop to add users in the result
	Foreach ($account in $collection)
	{
		$reportDatU += New-Object -TypeName psObject -Property @{ sAMAccountName = $account.sAMAccountName
																  PrimaryGroupID = $account.PrimaryGroupID
																  DisplayName    = $account.Name
																  ObjectClass    = "User"
																}
	}

	#.If empty...
	if ($reportDatU.count -eq 0)
	{
		$reportDatU += New-Object -TypeName psObject -Property @{ sAMAccountName = "no object found!"
																  PrimaryGroupID = $null
																  DisplayName    = $null
																  ObjectClass    = $Null
																}
	}

	#.Grabbing Computer elements
	$collection = Get-ADComputer -Filter { PrimaryGroupID -ne "515" } -Properties PrimaryGroupID | Where-Object { $_.sAMAccountName -notmatch $arDCs }

	#.Loop to add users in the result
	Foreach ($account in $collection)
	{
		$reportDatC += New-Object -TypeName psObject -Property @{ sAMAccountName = $account.sAMAccountName
																  PrimaryGroupID = $account.PrimaryGroupID
																  DisplayName    = $account.Name
																  ObjectClass    = "User"
																}
	}

	#.If empty...
	if ($reportDatC.count -eq 0)
	{
		$reportDatC += New-Object -TypeName psObject -Property @{ sAMAccountName = "no object found!"
																  PrimaryGroupID = $null
																  DisplayName    = $null
																  ObjectClass    = $Null
																}
	}

	#.Grabbing DC elements
	$collection = Get-ADDomainController 

	#.Loop to add users in the result
	Foreach ($account in $collection)
	{
		$CptrData = Get-ADComputer -Identity $account.Name -Properties PrimaryGroupID

		if ($CptrData.PrimaryGroupID -ne 516)
		{
			$reportDatD += New-Object -TypeName psObject -Property @{ sAMAccountName = $account.sAMAccountName
																	  PrimaryGroupID = $account.PrimaryGroupID
																	  DisplayName    = $account.Name
																	  ObjectClass    = "User"
																	}
		}
	}

	#.If empty...
	if ($reportDatD.count -eq 0)
	{
		$reportDatD += New-Object -TypeName psObject -Property @{ sAMAccountName = "no object found!"
																  PrimaryGroupID = $null
																  DisplayName    = $null
																  ObjectClass    = $Null
																}
	}

	#.Convert to html
	$myReportU = Export-HtmlFunctionReport -FunctionData $FunctionDatU -reportData $reportDatU -SortData @("sAMAccountName","ObjectClass","DisplayName","PrimaryGroupID")
	$myReportC = Export-HtmlFunctionReport -FunctionData $FunctionDatC -reportData $reportDatC -SortData @("sAMAccountName","ObjectClass","DisplayName","PrimaryGroupID")
	$myReportD = Export-HtmlFunctionReport -FunctionData $FunctionDatD -reportData $reportDatD -SortData @("sAMAccountName","ObjectClass","DisplayName","PrimaryGroupID")

	#.Output result
	Try { 
		$myReportU | out-file (".\Results\" + $ScriptName + "_Users.html") -encoding UTF8 -Force
		$myReportC | out-file (".\Results\" + $ScriptName + "_Computers.html") -encoding UTF8 -Force
		$myReportD | out-file (".\Results\" + $ScriptName + "_DCs.html") -encoding UTF8 -Force
		$result = 0
	}
	Catch {
		$result = 2
	}

	#.leave function 
	return $result
}

Function Search-AdminAccountNotMemberOfProtectedUsers
{
	<#  .SYNOPSIS 
		Function to search for Accounts Set with AdminCount = 1 and not member of Protected Users.
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
	$FunctionData = "Accounts With 'AdminCount=1' Not Member of 'Protected Users'"
															 
	#.Grabbing elements (taking into account regional country naming)
	$AdminCountAcc = Get-ADUser -Filter { AdminCount -eq 1 -and name -ne "krbtgt" } -Properties AdminCount
	$PrtUsrGrpName = (Get-ADGroup -Identity ([String](Get-ADDomain).DomainSID + "-525")).sAMAccountName
	$PrtUsrGrpMbrs = Get-ADGroupMember $PrtUsrGrpName

	#.Check if the group is not empty. If so, generate an empty table to let the compare object works.
	if ($PrtUsrGrpMbrs -eq $null) 
	{
		$PrtUsrGrpMbrs = New-Object -TypeName psobject -Property @{ sAMAccountName = "" }
	}

	#.Compare data
	$arNotMembers = Compare-Object $PrtUsrGrpMbrs.sAMAccountName $AdminCountAcc.sAMAccountName | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object InputObject

	#.Loop to add users in the result
	Foreach ($account in $arNotMembers)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = $account.InputObject 
																  "Protected Users Group" = "Not Member"
																}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "No missing object!" 
																  "Protected Users Group" = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","Protected Users Group")

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

Function Search-AdminAccountNotDefinedAsSensible
{
	<#  .SYNOPSIS 
		Function to search for Accounts Set with AdminCount = 1 and not set with parameter account could not be delegated.
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
	$FunctionData = "Accounts With 'AdminCount=1' Not flagged as 'account is sensible and cannot be delegated'"
															 
	#.Grabbing elements (taking into account regional country naming)
	$AdminCountAcc = Get-ADUser -Filter { AdminCount -eq 1 -and name -ne "krbtgt" } -Properties AdminCount

	#.Loop to add users in the result
	Foreach ($account in $AdminCountAcc)
	{
		if ((Get-ADUser $account -Properties AccountNotDelegated).AccountNotDelegated -eq $false)
		{
				$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = $account.sAMAccountName
																		  Enabled = $account.Enabled
																		  "account is sensible and cannot be delegated" = $false
																		}
		}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "No object found"
																  Enabled = $null
																  "account is sensible and cannot be delegated" = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","Enabled","account is sensible and cannot be delegated")

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

Function Search-AccountsWithDESenabled
{
	<#  .SYNOPSIS 
		Function to search for Accounts set with DES Key allowed.
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
	$FunctionData = "Accounts set with DES enabled on Kerberos"
															 
	#.Grabbing elements (taking into account regional country naming)
	$UserAccounts = Get-ADUser -Filter { UseDESKeyOnly -eq $true } -Properties UseDESKeyOnly

	#.Loop to add users in the result
	Foreach ($account in $UserAccounts)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = $account.sAMAccountName 
																  "DES Key Only" = $account.UseDESKeyOnly
																  Enabled = $account.Enabled
																}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "No object found" 
																  "DES Key Only" = $null
																  Enabled = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","Enabled","DES Key Only")

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

Function Search-AccountsTrustedForUnconstrainedDelegation
{
	<#  .SYNOPSIS 
		Function to search for Accounts trusted for unconstrained delegation.
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
	$FunctionData = "Accounts allowed for untrusted for delegation"
															 
	#.Grabbing elements (taking into account regional country naming)
	$UserAccounts = Get-ADUser -Filter { TrustedForDelegation -eq $true } -Properties TrustedForDelegation
	$CptrAccounts = Get-ADComputer -Filter { TrustedForDelegation -eq $true } -Properties TrustedForDelegation | Where-Object { $_.Name -notmatch (Get-ADDomainController).Name }

	#.Loop to add users in the result
	Foreach ($account in $UserAccounts)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = $account.sAMAccountName 
																  "Trusted for Unconstrained Delegation" = $account.TrustedForDelegation
																  Enabled = $account.Enabled
																  ObjectClass = "User"
																}
	}

	Foreach ($account in $CptrAccounts)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = $account.sAMAccountName 
																  "Trusted for Unconstrained Delegation" = $account.TrustedForDelegation
																  Enabled = $account.Enabled
																  ObjectClass = "Computer"
																}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "No object found" 
																  "Trusted for Unconstrained Delegation" = $null
																  Enabled = $null
																  ObjectClass = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","ObjectClass","Enabled","Trusted for Unconstrained Delegation")

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

Function Search-AccountsWithServicePrincipalName
{
	<#  .SYNOPSIS 
		Function to search for Accounts set with a service principal name (user only).
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
	$FunctionData = "User Objects defined with a ServicePrincipalName"
															 
	#.Grabbing elements (taking into account regional country naming)
	$UserAccounts = Get-ADUser -Filter {sAMAccountName -ne "krbtgt" } -Properties ServicePrincipalNames | Where-Object { $_.ServicePrincipalNames -ne $null }

	#.Loop to add users in the result
	Foreach ($account in $UserAccounts)
	{
		foreach ($SPN in $account.ServicePrincipalNames)
		{
			$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = $account.sAMAccountName 
																	  Enabled = $account.Enabled
																	  ObjectClass = "User"
																	  ServicePrincipalName = $SPN
																	}
		}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "No object found" 
																  "Trusted for Unconstrained Delegation" = $null
																  Enabled = $null
																  ObjectClass = $null
																  ServicePrincipalName = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","ObjectClass","Enabled","ServicePrincipalName")

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