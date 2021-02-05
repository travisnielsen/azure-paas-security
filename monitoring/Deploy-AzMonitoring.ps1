<#
.SYNOPSIS
Deploys monitoring - alerts and dashboard for resources

.DESCRIPTION
Deploys monitoring - alerts and dashboard for resources

.PARAMETER SubscriptionId
The event grid data content recieved on resource modification

.PARAMETER ResourceGroupName
The event grid data content recieved on resource modification

.PARAMETER Location
The event grid data content recieved on resource modification

.PARAMETER ActionGroupName
The event grid data content recieved on resource modification

.EXAMPLE
Deploy-AzMonitoring -WorkspaceSubscriptionId <1111-2222-44444> -WorkspaceResourceGroupName <some-name-rg> -WorkspaceName <some-name> -ParameterFilePath </path/to/param>

.NOTES
Deploy using ARM templates
#>
function Deploy-AzMonitoring {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # Parameter help description
        [Parameter(Mandatory = $false)]
        [string] $SubscriptionId,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [string] $Location,

        # Parameter help description
        [Parameter(Mandatory)]
        [string] $ActionGroupName
    )

    # Toek replacement extension in ADO will replace all parameter values automatically
    # Deployment will reference parameter file during deployment

    begin {
        Write-Debug ("[{0} entered]" -f $MyInvocation.MyCommand)

        # Set appropriate subscription context
        $null = Set-AzContext $SubscriptionId -Scope Process -ErrorAction Stop
    }

    process {
        $deploymentInputsArgs = @{}

        # region Validate/create Action grouip exists
        $actionGroup = Get-AzActionGroup -ResourceGroupName $ResourceGroupName -Name $ActionGroupName -ErrorAction SilentlyContinue
        if ($null -eq $actionGroup) {
            Write-Host "Action group - '$($ActionGroupName)' does not exist... creating"

            $agTemplateFilePath = (Get-ChildItem -Path "../monitoring" -Recurse).FullName
            if (!(Test-Path $TemplateFile)) {
                $TemplateFile = $agTemplateFilePath + '/actionGroup.json'
            }

            Write-Verbose "Deploying action group..." -Verbose
            New-AzResourceGroupDeployment -TemplateFile $TemplateFile -ResourceGroupName $ResourceGroupName -Verbose -ErrorVariable ActionGroupFailed
            if ($ActionGroupFailed) {
                Write-Error "Failed to deploy action group - '$($ActionGroupName)'" -ErrorAction Stop
            }

            Write-Verbose "Successfully deployed action group" -Verbose
        }
        #endregion action group

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