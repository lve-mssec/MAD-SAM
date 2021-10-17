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

Export-ModuleMember -Function *