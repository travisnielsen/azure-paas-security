param appPrefix string
param environment string {
  allowed: [
    'dev'
    'uat'
    'prod'
  ]
}
param tags object = {
  project: 'AzSecurePaaS'
  component: 'app'
}

param sqlAdminLoginName string
param sqlAdminLoginPwd string {
  secure: true
}
param sqlAdminObjectId string

param storageContainerName string = 'testdata'
param sqlDatabaseName string = 'nytaxi'
param sqlDatabaseSKU string = 'DW100c'

// VNet integration
var subscriptionId = subscription().subscriptionId
var region = resourceGroup().location
var networkResourceGroupName = '${appPrefix}-${environment}-network'
var vnetName = '${appPrefix}-${region}-${environment}-app'

var sqlServerName = '${uniqueString(resourceGroup().id)}-${environment}-sql'
var dataFactoryName = '${uniqueString(resourceGroup().id)}-${environment}-df'
var storageAccountName = '${uniqueString(resourceGroup().id)}${environment}storg'

var logAnalyticsName = '${uniqueString(resourceGroup().id)}-${environment}'

/*
 *  Storage account
 */
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
  name: '${storageAccount.name}/default/${storageContainerName}'
  dependsOn: [
    storageAccount
  ]
}

/*
 *  Log Analytics
 */
module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'logAnalytics'
  params: {
    name: logAnalyticsName
    appTags: tags
  }
}


module storagePrivateEndpoint 'modules/privateendpoint.bicep' = {
  name: 'storageAccount-privateEndpoint'
  dependsOn: [
    storageAccount
  ]
  params: {
    privateEndpointName: '${storageAccount.name}-${environment}-storageEndpoint'
    serviceResourceId: storageAccount.id
    resourceGroupNameNetwork: networkResourceGroupName
    vnetName: vnetName
    subnetName: 'azureServices'
    // dnsZoneId: resourceId(subscriptionId, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.core.windows.net' )
    dnsZoneName: 'privatelink.blob.core.windows.net'
    groupId: 'blob'
  }
}

/*
 *  Dedicated SQL Pool (SQL DW) instance
 */
module sqlSynapse 'modules/sqlpool.bicep' = {
  name: 'sql-dedicatedpool'
  params: {
    sqlServerName: sqlServerName
    sqlPoolName: sqlDatabaseName
    sqlPoolSKU: sqlDatabaseSKU
    adminLoginName: sqlAdminLoginName
    adminLoginPwd: sqlAdminLoginPwd
    adminObjectId: sqlAdminObjectId
    resourceGroupNameNetwork: networkResourceGroupName
    vnetNamePrivateEndpoint: vnetName
    subnetNamePrivateEndpoint: 'azureServices'
    //logAnalyticsWorkspaceId: logAnalytics.outputs.id
    tags: tags
  }
}

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  dependsOn: [
    storageAccount
    sqlSynapse
  ]
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

module dataFactoryPrivateEndpoint 'modules/privateendpoint.bicep' = {
  name: 'datafactory-privateEndpoint'
  dependsOn: [
    dataFactory
  ]
  params: {
    privateEndpointName: '${dataFactory.name}-${environment}-dataFactoryEndpoint'
    serviceResourceId: dataFactory.id
    resourceGroupNameNetwork: networkResourceGroupName
    vnetName: vnetName
    subnetName: 'azureServices'
    dnsZoneName: 'privatelink.datafactory.azure.net'
    groupId: 'dataFactory'
  }
}

resource dataFactoryManagedVNET 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  name: '${dataFactory.name}/default'
  properties: {
  }
}

resource integrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  name: '${dataFactory.name}/AutoResolveIntegrationRuntime'
  dependsOn: [
    dataFactory
    dataFactoryManagedVNET
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

// ADF: Managed private endpoints

resource managedPrivEndpointSql 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = {
  name: '${dataFactory.name}/default/SqlSynapse1'
  dependsOn: [
    dataFactoryManagedVNET
  ]
  properties: {
    groupId: 'sqlServer'
    privateLinkResourceId: sqlSynapse.outputs.id
  }
}

resource managedPrivEndpointBlob 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = {
  name: '${dataFactory.name}/default/BlobStorage1'
  dependsOn: [
    dataFactoryManagedVNET
    storagePrivateEndpoint
  ]
  properties: {
    groupId: 'blob'
    privateLinkResourceId: storageAccount.id
  }
}

// TODO: Create CLI script to approve private link service connection created by the ADF Managed Private Endpoints settings

// ADF: Linked services

resource adfLinkedServiceSql 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: '${dataFactory.name}/SqlSynapse1'
  dependsOn: [
    integrationRuntime
  ]
  properties: {
    type: 'AzureSqlDW'
    typeProperties: {
      connectionString: 'Integrated Security=False;Encrypt=True;Connection Timeout=30;Data Source=${sqlServerName}.database.windows.net;Initial Catalog=${sqlDatabaseName}'
    }
    connectVia: {
      referenceName: 'AutoResolveIntegrationRuntime'
      type: 'IntegrationRuntimeReference'
    }
  }
}

resource adfLinkedServiceBlob 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: '${dataFactory.name}/BlobStorage1'
  dependsOn:[
    integrationRuntime
  ]
  properties: {
    type: 'AzureBlobStorage'
    typeProperties: {
      serviceEndpoint: 'https://${storageAccount.name}.blob.core.windows.net'
      accountKind: storageAccount.kind
    }
    connectVia: {
      referenceName: 'AutoResolveIntegrationRuntime'
      type: 'IntegrationRuntimeReference'
    }
  }
}

// Storage: Grant data read access to ADF managed identity

// var roleAssignmentName_var = guid(resourceId('Microsoft.Storage/storageAccounts/', storageAccount.name), 'ba92f5b4-2d11-453d-a403-e96b0029c9fe', dataFactory.name)

resource roleAssignmentName 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageAccount.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe', dataFactory.name)
  dependsOn: [
    storageAccount
    dataFactory
  ]
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: dataFactory.identity.principalId
  }
  scope: storageAccount
}