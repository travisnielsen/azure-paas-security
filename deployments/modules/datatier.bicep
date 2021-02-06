param storageAccountName string
param storageContainerName string
param adfName string
param tags object
param networkResourceGroupName string
param vnetName string
param sqlServerName string
param sqlAdminLoginName string
param sqlAdminLoginPwd string
param sqlAdminObjectId string
param actionGroupId string

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
  tags: tags
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${storageAccountName}/default/${storageContainerName}'
}

module storagePrivateEndpoint 'privateendpoint.bicep' = {
  name: 'storageAccount-privateEndpoint'
  dependsOn: [
    storageAccount
  ]
  params: {
    privateEndpointName: '${storageAccountName}-storageEndpoint'
    serviceResourceId: storageAccount.id
    resourceGroupNameNetwork: networkResourceGroupName
    vnetName: vnetName
    subnetName: 'azureServices'
    // dnsZoneId: resourceId(subscriptionId, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.core.windows.net' )
    dnsZoneName: 'privatelink.blob.core.windows.net'
    groupId: 'blob'
  }
}

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

resource whenadfactivityfailed 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'whenadfactivityfailed'
  location: 'global'
  properties: {
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
    autoMitigate: true
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: []
          metricName: 'ActivityFailedRuns'
          metricNamespace: 'Microsoft.DataFactory/factories'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 1
          timeAggregation: 'Total'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'send alert when adf activity failed'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      resourceId('Microsoft.DataFactory/factories', dataFactory.name)
    ]
    severity: 4
    targetResourceType: 'Microsoft.DataFactory/factories'
    windowSize: 'PT1M'
  }
  dependsOn: [
    dataFactory
  ]
}

resource whenadfpipelinefailed 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'whenadfpipelinefailed'
  location: 'global'
  properties: {
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
    autoMitigate: true
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: []
          metricName: 'PipelineFailedRuns'
          metricNamespace: 'Microsoft.DataFactory/factories'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 1
          timeAggregation: 'Total'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'send alert when adf pipeline is failed'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      resourceId('Microsoft.DataFactory/factories', dataFactory.name)
    ]
    severity: 4
    targetResourceType: 'Microsoft.DataFactory/factories'
    windowSize: 'PT1M'
  }
  dependsOn: [
    dataFactory
  ]
}

resource whenadftriggerfailed 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'whenadftriggerfailed'
  location: 'global'
  properties: {
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
    autoMitigate: true
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: []
          metricName: 'TriggerFailedRuns'
          metricNamespace: 'Microsoft.DataFactory/factories'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 1
          timeAggregation: 'Total'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'send alert when adf trigger failed'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      resourceId('Microsoft.DataFactory/factories', dataFactory.name)
    ]
    severity: 4
    targetResourceType: 'Microsoft.DataFactory/factories'
    windowSize: 'PT1M'
  }
  dependsOn: [
    dataFactory
  ]
}

module dataFactoryPrivateEndpoint 'privateendpoint.bicep' = {
  name: 'datafactory-privateEndpoint'
  dependsOn: [
    dataFactory
  ]
  params: {
    privateEndpointName: '${dataFactory.name}-dataFactoryEndpoint'
    serviceResourceId: dataFactory.id
    resourceGroupNameNetwork: networkResourceGroupName
    vnetName: vnetName
    subnetName: 'azureServices'
    dnsZoneName: 'privatelink.datafactory.azure.net'
    groupId: 'dataFactory'
  }
}

resource managedVNET 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  name: '${dataFactory.name}/default'
  properties: { 
  }
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

var roleAssignmentName_var = guid(resourceId('Microsoft.Storage/storageAccounts/', storageAccountName), 'ba92f5b4-2d11-453d-a403-e96b0029c9fe', dataFactory.name)

resource roleAssignmentName 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentName_var
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: dataFactory.identity.principalId
  }
  scope: storageAccount
}

// Synapse SQL
module sqlSynapse 'sqlpool.bicep' = {
  name: 'sql-dedicatedpool'
  dependsOn: [
  ]
  params: {
    serverName: sqlServerName
    sqlPoolName: 'testdb'
    sqlPoolSKU: 'DW100c'
    adminLoginName: sqlAdminLoginName
    adminLoginPwd: sqlAdminLoginPwd
    adminObjectId: sqlAdminObjectId
    resourceGroupNameNetwork: networkResourceGroupName
    vnetNamePrivateEndpoint: vnetName
    subnetNamePrivateEndpoint: 'azureServices'
    tags: tags
  }
}