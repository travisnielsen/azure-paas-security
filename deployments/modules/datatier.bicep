param storageAccountName string
param storageContainerName string
param adfName string
param tags object


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

output storageAccountId string = storageAccount.id
output storageAccountApiVersion string = storageAccount.apiVersion
output dataFactoryId string = dataFactory.id