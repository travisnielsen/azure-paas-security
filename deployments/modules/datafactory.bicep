param adfName string
param workspaceName string

var workspaceResourceId = resourceId('Microsoft.OperationalInsights/workspaces', workspaceName)
var disgnosticsName = 'adfdiagnostics'

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: adfName
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    /*
    repoConfiguration: {
      type: 'FactoryVSTSConfiguration'
      accountName: ''
      projectName: ''
      repositoryName: ''
      collaborationBranch: ''
      rootFolder: ''
    }
    */
  }
}

resource dataFactoryDiag 'Microsoft.DataFactory/factories/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${dataFactory.name}/Microsoft.Insights/${disgnosticsName}'
  location: resourceGroup().location
  properties: {
    storageAccountId: null
    eventHubAuthorizationRuleId: null
    eventHubName: null
    workspaceId: workspaceResourceId
    logs: [
      {
          category: 'TriggerRuns'
          enabled: true
      }
      {
          category: 'PipelineRuns'
          enabled: true
      }
      {
          category: 'ActivityRuns'
          enabled: true
      }
    ]
    metrics: [
      {
          category: 'AllMetrics'
          enabled: true
      }
  ]
  logAnalyticsDestinationType: 'Dedicated'
  }
  dependsOn: [
    dataFactory
  ]
}

resource managedVNET 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  name: '${dataFactory.name}/default'
  properties: {}
}

resource integrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  name: '${adfName}/AutoResolveIntegrationRuntime'
  dependsOn: [
    dataFactory
    managedVNET
  ]
  properties: {
    type: 'Managed'
    managedVirtualNetwork: {
      referenceName: 'default'
      type: 'ManagedVirtualNetworkReference'
    }
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
      }
    }
  }
}

// TODO: need to finsih configuration
/*
resource privateLink 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = {
  name: '${name}/something'
  properties: {
    
  }
}
*/

output id string = dataFactory.id
output name string = dataFactory.name