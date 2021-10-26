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
	$FunctionData = New-Object -TypeName psobject -Property @{ ScriptName=$ScriptName
															   ScriptDesc="List user accounts with no activity during at least $inactiveFor days"
															 }

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