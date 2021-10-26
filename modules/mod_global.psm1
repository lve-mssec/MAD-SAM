Function Grant-Scheduler
{
	<#  .SYNOPSIS
		 This function grant the scheduler account to the specified group.
		
		.NOTES
		 Version 01.00.000
		  Author loic.veirman@mssec.fr
	#>
	Param(
		[Parameter(mandatory=$true)]
		[String]
		$targetGroup
	)

	#.Init logging
	$LogName = ".\Logs\Global_Grant-Scheduler.log"
	$LogData = @()

	#.Start
	$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "START`t########## FUNCTION STARTS ##########"

	#.Granting account
	Try {
		$svcAccount = ([xml](Get-Content .\Configs\Configuration.xml)).Settings.AccountName
		$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "INFO `tService Account Name: $svcAccount"
		$opeCode = $True
	}
	Catch {
		$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "ERROR`tXML could not be read. Leaving"
		$opeCode = $False
	}

	if ($opeCode)
	{
		$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "INFO `tGranting privileges"
		Try {
			Add-ADGroupMember -identity $targetGroup -Members $svcAccount -confirm:$False
			$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "INFO `t$svcAccount added successfully to $targetGroup"
			$opeCode = $True
		}
		Catch {
		$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "ERROR`tFalied to add $svcAccount to $targetGroup"
		$opeCode = $False			
		}
	}
	#.return code
	switch ($opCode)
	{
		$True {
			$result = 0
		}

		$False {
			$result = 2
		}
	}
	
	$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "OVER `t########## FUNCTION ENDS   ##########"
	$LogData | out-file $LogName -Append

	return $result
}

Function Ungrant-Scheduler
{
	<#  .SYNOPSIS
		 This function remove the scheduler account from the specified group.
		
		.NOTES
		 Version 01.00.000
		  Author loic.veirman@mssec.fr
	#>
	Param(
		[Parameter(mandatory=$true)]
		[String]
		$targetGroup
	)

	#.Init logging
	$LogName = ".\Logs\Global_Ungrant-Scheduler.log"
	$LogData = @()

	#.Start
	$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "START`t########## FUNCTION STARTS ##########"

	#.Granting account
	Try {
		$svcAccount = ([xml](Get-Content .\Configs\Configuration.xml)).Settings.AccountName
		$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "INFO `tService Account Name: $svcAccount"
		$opeCode = $True
	}
	Catch {
		$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "ERROR`tXML could not be read. Leaving"
		$opeCode = $False
	}

	if ($opeCode)
	{
		$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "INFO `tGranting privileges"
		Try {
			Remove-ADGroupMember -identity $targetGroup -Members $svcAccount -confirm:$False
			$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "INFO `t$svcAccount removed successfully from $targetGroup"
			$opeCode = $True
		}
		Catch {
		$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "ERROR`tFalied to remove $svcAccount from $targetGroup"
		$opeCode = $False			
		}
	}
	#.return code
	switch ($opCode)
	{
		$True {
			$result = 0
		}

		$False {
			$result = 2
		}
	}

	$LogData += (Get-Date -Format "yyyy-MM-dd`thh:mm:ss`t") + "OVER `t########## FUNCTION ENDS   ##########"
	$LogData | out-file $LogName -Append

	return $result
}

Function Export-HtmlFunctionReport
{
	<#  .SYNOPSIS
		This function ease the html report building by formating all of them the same way.

		.PARAMETER FunctionData
		A string to resume the table content.

		.PARAMETER ReportData
		Array. Shoud contains a custom table as for a csv export. The script will adapt it with a proper formating.

		.PARAMETER SortData
		Array. Should list table header in prefered order to ensure every report is presented the same way (call with @("id1","id2",...)).

		.NOTE
		Version 01.00 by loic.veirman@mssec.fr
	#>

	Param(
		[Parameter(mandatory=$true)]
		[String]
		$FunctionData,

		[Parameter(mandatory=$true)]
		$ReportData,

		[Parameter(Mandatory=$true)]
		$SortData
	)

	#.CSS Style
	$Header  = '<Style>'
	$Header += '  h1    { font-family: Arial, Helvetica, sans-serif; color: #e68a00; font-size: 28px; }'
	$Header += '  h2    { font-family: Arial, Helvetica, sans-serif; color: #1E90FF; font-size: 16px; }'
	$Header += '  h3    { font-family: Arial, Helvetica, sans-serif; color: #FF7F50; font-size: 12px; }'
	$Header += '  table { font-family: Arial, Helvetica, sans-serif; font-size: 12px; border: 0px; }'
	$Header += '  td    { Padding: 4px; Margin: 0px; border: 0; background: #e8e8e8;} '
	$Header += '  th    { background: #395870; background: linear-gradiant(#49708f, #293f50); color: #fff; font-size: 11px; text-transform: uppdercase; padding: 4px 4px; text-align: left; }'
	$Header += '</Style>'

	#.Prepending data
	$PreContent += "<h2>$FunctionData</h2>"
	$PreContent += "<h3>Date d'ex�cution : "  + (Get-Date -format "dd/MM/yyyy - HH:mm:ss") + "</h3>"

	#.Preparing the html report
	$reportHtml = $ReportData | ConvertTo-Html -Fragment -PreContent $PreContent -Property $SortData

	#.Getting final result
	$report = ConvertTo-Html -Body $reportHtml -Head $Header 

	#.reporting result to caller
	return $Report
}

Export-ModuleMember -Function *