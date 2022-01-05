Function Search-AccountsWithNoActivity
{
	<#  .SYNOPSIS 
		Function to search for Active User Accounts that remains enable but has no activity for the last 90 days.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.PARAMETER InactiveFor
		 Specify the minimum number of days of inactivity to be considered has really inactive.

		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Oct. 2021
	#>

	Param (
		[Parameter(mandatory=$true)]
		[int]
		$InactiveFor
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "User accounts with no activity during at least $inactiveFor days"

	#.Grabbing elements
	$inactiveUsers = search-AdAccount -UsersOnly -AccountInactive -Timespan $InactiveFor

	#.Loop to add users in the result
	Foreach ($account in $inactiveUsers)
	{
		$lastlogon = [DateTime]::FromFileTime((Get-ADUser $account.sAMAccountName -Properties LastLogonTimeStamp).LastLogonTimeStamp)

		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = $account.sAMAccountName
																  LastSeen       = $lastlogon
																  InactiveDays   = ((Get-Date) - $lastlogon).Days
																}
	}
	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "no object found!"
																  LastSeen       = $null
																  InactiveDays   = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","LastSeen","InactiveDays")

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

Function Search-AccountsWithTooOldPassword
{
	<#  .SYNOPSIS 
		Function to search for Active User Accounts that have not changed their password for a long period of time.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.PARAMETER MaxPasswordAge
		 Specify the maximum number of days above which the password is considered as risky.

		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Oct. 2021
	#>

	Param (
		[Parameter(mandatory=$true)]
		[int]
		$MaxPasswordAge
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "User accounts with a password older than $MaxPasswordAge days"
															 
	#.Grabbing elements
	$OldPwds = Get-ADUser -Filter { enabled -eq $true } -Properties pwdLastSet | Where-Object { [DateTime]::FromFileTime($_.pwdLastSet) -ge (Get-Date).AddDays($MaxPasswordAge) }

	#.Loop to add users in the result
	Foreach ($account in $OldPwds)
	{
		$PwdAge = ((Get-Date) - [DateTime]::FromFileTime($account.pwdLastSet)).Days

		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = $account.sAMAccountName
																  PwdLastSet     = [DateTime]::FromFileTime($account.pwdLastSet)
																  PwdAge         = $PwdAge
																}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "no object found!"
																  PwdLastSet     = $null
																  PwdAge         = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","PwdAge","PwdLastSet")

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

Function Search-AccountsWithPasswordNeverExpires
{
	<#  .SYNOPSIS 
		Function to search for Active User Accounts that have a password set to never expires.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Oct. 2021
	#>

	Param (
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "User accounts with a password that never expires"
															 
	#.Grabbing elements
	$BadPwds = Get-ADUser -Filter { enabled -eq $true -and passwordNeverExpires -eq $true } -Properties PasswordNeverExpires, pwdLastSet

	#.Loop to add users in the result
	Foreach ($account in $BadPwds)
	{
		$PwdAge = ((Get-Date) - [DateTime]::FromFileTime($account.pwdLastSet)).Days

		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName  = $account.sAMAccountName
																  PwdLastSet      = [DateTime]::FromFileTime($account.pwdLastSet)
																  PwdAge          = $PwdAge
																  PwdNeverExpires = $account.passwordNeverExpires 
																}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "no object found!"
																  PwdLastSet      = $null
																  PwdAge          = $null
																  PwdNeverExpires = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","PwdAge","PwdLastSet","PwdNeverExpires")

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

Function Search-AccountsWithPasswordNotRequiered
{
	<#  .SYNOPSIS 
		Function to search for Active User Accounts that have a password set to not requiered - i.e. could be empty.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Oct. 2021
	#>

	Param (
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "User accounts set with the attribute PasswordNotRequired enabled"
															 
	#.Grabbing elements
	$BadPwds = Get-ADUser -Filter { enabled -eq $true -and PasswordNotRequired -eq $true } -Properties PasswordNeverExpires, pwdLastSet, PasswordNotRequired

	#.Loop to add users in the result
	Foreach ($account in $BadPwds)
	{
		$PwdAge = ((Get-Date) - [DateTime]::FromFileTime($account.pwdLastSet)).Days

		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName  = $account.sAMAccountName
																  PwdLastSet      = [DateTime]::FromFileTime($account.pwdLastSet)
																  PwdAge          = $PwdAge
																  PwdNeverExpires = $account.passwordNeverExpires 
																  PwdNotRequired  = $account.PasswordNotRequired
																}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "no object found!"
																  PwdLastSet      = $null
																  PwdAge          = $null
																  PwdNeverExpires = $null
																  PwdNotRequired  = $null 
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","PwdNotRequired","PwdAge","PwdLastSet","PwdNeverExpires")

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

Function Search-AccountsWithReversiblePassword
{
	<#  .SYNOPSIS 
		Function to search for Active User Accounts that have a password reversible, which indeed let them being readable by anyone.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Oct. 2021
	#>

	Param (
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "User accounts set with a reversible password"
															 
	#.Grabbing elements
	$BadPwds = Get-ADUser -Filter { enabled -eq $true -and userAccountControl -band 128 } -Properties PasswordNeverExpires, pwdLastSet, PasswordNotRequired, userAccountControl

	#.Loop to add users in the result
	Foreach ($account in $BadPwds)
	{
		$PwdAge = ((Get-Date) - [DateTime]::FromFileTime($account.pwdLastSet)).Days

		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName  = $account.sAMAccountName
																  PwdLastSet      = [DateTime]::FromFileTime($account.pwdLastSet)
																  PwdAge          = $PwdAge
																  PwdNeverExpires = $account.passwordNeverExpires 
																  PwdReversible   = $true
																}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "no object found!"
																  PwdLastSet      = $null
																  PwdAge          = $null
																  PwdNeverExpires = $null
																  PwdReversible   = $null 
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","PwdReversible","PwdAge","PwdLastSet","PwdNeverExpires")

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

Function Export-SensibleGroupMembers
{
	<#  .SYNOPSIS 
		Function to retrieve group membership for sensible group.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Oct. 2021
	#>

	Param (
		[Parameter(mandatory=$true)]
		[String]
		$groupName
	)

	#.Adjust if a SID is used
	if ($groupName -like "S-1-5-*")
	{
		$groupName = (Get-ADGroup $groupName).sAMAccountName
	}

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName-$groupName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "Users and Groups belonging to $groupName"
															 
	#.Grabbing elements
	$collection = Get-ADGroupMember -Identity $groupName

	#.Loop to add users in the result
	Foreach ($account in $collection)
	{
		$PwdAge = ((Get-Date) - [DateTime]::FromFileTime($account.pwdLastSet)).Days

		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName  = $account.sAMAccountName
																  ObjectClass     = $account.objectClass
																}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "no object found!"
																  ObjectClass    = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","objectClass")

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

Function Search-ComputersWithPasswordNeverExpires
{
	<#  .SYNOPSIS 
		Function to search for Computers that have a password set to never expires.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Oct. 2021
	#>

	Param (
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "Computer objects with a password that never expires"
															 
	#.Grabbing elements
	$BadPwds = Get-ADComputer -Filter { enabled -eq $true -and passwordNeverExpires -eq $true } -Properties PasswordNeverExpires, pwdLastSet

	#.Loop to add users in the result
	Foreach ($account in $BadPwds)
	{
		$PwdAge = ((Get-Date) - [DateTime]::FromFileTime($account.pwdLastSet)).Days

		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName  = $account.sAMAccountName
																  PwdLastSet      = [DateTime]::FromFileTime($account.pwdLastSet)
																  PwdAge          = $PwdAge
																  PwdNeverExpires = $account.passwordNeverExpires 
																}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName = "no object found!"
																  PwdLastSet      = $null
																  PwdAge          = $null
																  PwdNeverExpires = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","PwdAge","PwdLastSet","PwdNeverExpires")

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

Function Search-ComputerWithUnconstrainedDelegation
{
	<#  .SYNOPSIS 
		Function to search for Computers that have a password set to never expires.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Oct. 2021
	#>

	Param (
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "Computer objects with unconstrained delegation"
															 
	#.Grabbing elements
	$collection = Get-ADComputer -Filter { enabled -eq $true -and TrustedForDelegation -eq $true } -Properties TrustedForDelegation,TrustedToAuthForDelegation

	#.Loop to add users in the result
	Foreach ($account in $collection)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName          = $account.sAMAccountName
																  UnconstrainedDelegation = $account.TrustedForDelegation
																  ConstrainedDelegation   = $account.TrustedToAuthForDelegation
																}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ sAMAccountName          = "no object found!"
																  UnconstrainedDelegation = $null
																  ConstrainedDelegation   = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("sAMAccountName","UnconstrainedDelegation","ConstrainedDelegation")

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

Function Search-GroupPolicyBadOwnership
{
	<#  .SYNOPSIS 
		Function to search for Group Policy that have a wrong owner.
		The function will extract its data do an html file fo future reuse in a synthetic mail resume.
	
		.NOTES
		Version 01.00.000 by loic.veirman@mssec.Fr - Oct. 2021
	#>

	Param (
	)

	#.Script variable(s)
	$ScriptName = $MyInvocation.MyCommand
	$htmlName   = "$scriptName.html"
	$reportData = @()

	#.Function Data
	$FunctionData = "Group Policy with wrong ownership"
															 
	#.Building right owner's identity
	$ownerID = [String]((Get-ADDomain).NetBIOSName) + "\" + [String](Get-ADGroup ([string]((Get-ADDomain).DomainSID) + "-512")).sAMAccountName

	#.Grabbing elements
	$collection = Get-GPO -All | Where-Object { $_.Owner -ne $ownerID }

	#.Loop to add users in the result
	Foreach ($account in $collection)
	{
		$reportData += New-Object -TypeName psObject -Property @{ GpoName = $account.DisplayName
																  GpoID   = $account.ID
																  Owner   = $account.Owner
																}
	}

	#.If empty...
	if ($reportData.count -eq 0)
	{
		$reportData += New-Object -TypeName psObject -Property @{ GpoName = "no object found!"
																  GpoID   = $null
																  Owner   = $null
																}
	}

	#.Convert to html
	$myReport = Export-HtmlFunctionReport -FunctionData $FunctionData -reportData $reportData -SortData @("GpoName","Owner","GpoID")

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

Export-ModuleMember -Function *