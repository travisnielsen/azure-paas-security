<#
.SYNOPSIS
Deploys monitoring - alerts and dashboard for resources

.DESCRIPTION
Deploys monitoring - alerts and dashboard for resources

.PARAMETER ResourceGroupName
The resource group where all deployments will reside

.PARAMETER Location
The deployment region

.EXAMPLE
Deploy-AzMonitoring -ResourceGroupName <some-name-rg> -Location <some-region>

.NOTES
Deploy using ARM templates
#>
function Deploy-AzMonitoring {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # Parameter help description
        [Parameter(Mandatory = $false)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [string] $Location
    )

    # Token replacement extension in ADO will replace all parameter values automatically
    # Deployment will reference parameter files for each alert/dashboard

    begin {
        Write-Debug ("[{0} entered]" -f $MyInvocation.MyCommand)

        $null = Get-AzContext -ErrorAction Stop
    }

    process {
        $deploymentInputsArgs = @{}

        Write-Verbose 'Starting alerts/dashboard deployments...' -Verbose

        #region Get all prameters and print
		$param = ConvertFrom-Json (Get-Content -Raw -Path $parameterFilePath)
		$paramSet = @{ }
		$param.parameters | Get-Member -MemberType NoteProperty | ForEach-Object {
			$key = $_.Name
			$value = $param.parameters.($_.Name).Value
			if ($value -is [string]) {
				$formattedValue = $value.subString(0, [System.Math]::Min(15, $value.Length))
				if ($value.Length -gt 50) {
					$formattedValue += '...'
				}
			}
			else {
				$formattedValue = $value
			}

			$paramSet[$key] = $formattedValue
		}

		Write-Debug ($paramSet | Format-Table | Out-String) -Verbose

        $deploymentInputsArgs += @{
            Name                  = ("{0}-{1}" -f $SubscriptionId, (Get-Date -Format yyyMMddHHmmss))
            TemplateParameterFile = $ParameterFilePath
            Location              = $Location
            Verbose               = $true
            ErrorAction           = "Stop"
        }

        # Perform actual deployment of alerts or dashboard
        Write-Verbose 'Handling resource group level deployment' -Verbose
        $result = New-AzResourceGroupDeployment @deploymentInputsArgs -ResourceGroupName $ResourceGroupName -ErrorVariable ErrorMessages

        # Display error messages from Azure
        if ($ErrorMessages) {
            Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
        }
        else {
            if ($result.Outputs) {
                foreach ($outputkey in $result.Outputs.Keys) {
                    Write-Verbose ("Set [{0}] deployment output as pipeline environment variable with value: [{1}]" -f $outputkey, $result.Outputs[$outputkey].Value) -Verbose
                    Write-Host ("##vso[task.setvariable variable={0};isOutput=true]{1}" -f $outputkey, $result.Outputs[$outputkey].Value)
                }
            }
            Write-Verbose "Deployment successful" -Verbose
        }
    }

    end {
        Write-Debug ("[{0} existed]" -f $MyInvocation.MyCommand)
    }
}