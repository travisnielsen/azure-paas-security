targetScope = 'subscription'
param region string = 'centralus'
param appPrefix string

// Virtual Machine (jump)
param vmAdminUserName string = 'groot'
param vmAdminPwd string {
  secure: true
}

param tags object = {
  project: 'AzSecurePaaS'
}

param sqlAdminLoginName string = vmAdminUserName
param sqlAdminObjectId string

// VNet integration
var subscriptionId = subscription().subscriptionId
var networkResourceGroupName = '${appPrefix}-network'
var vnetName = '${appPrefix}-${region}-app'

/*
var tags = {
  AppID: 'paasdemo'
  CostCenter: 'abc123'
}
*/

// Create Resource Groups
resource resourceGroupUtil 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${appPrefix}-util'
  location: region
}

resource resourceGroupData 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${appPrefix}-data'
  location: region
}

resource resourceGroupApp 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${appPrefix}-app'
  location: region
}

// Log Analytics resource
module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'logAnalytics'
  scope: resourceGroup(resourceGroupApp.name)
  params: {
    name: uniqueString(resourceGroupApp.id)
    appTags: tags
  }
  dependsOn:[
    resourceGroupApp
  ]
}

// Deploy Action Group for monitoring/alerting
module actionGroup 'modules/actionGroup.bicep' = {
  name: 'actionGroup'
  scope: resourceGroup(resourceGroupApp.name)
  params: {
    actionGroupName: 'wbademoadmin'
    actionGroupShortName: 'wbademoadmin'
  }
}

// App Insights resource
module appInsights 'modules/appinsights.bicep' = {
  name: 'appInsights'
  scope: resourceGroup(resourceGroupApp.name)
  params: {
    name: uniqueString(resourceGroupApp.id)
    logAnalyticsId: logAnalytics.outputs.id
    actionGroupName: actionGroup.name
    tags: tags
  }
}

// Storage account for data
module storageAccount 'modules/storageaccount.bicep' = {
  name: 'storageAccount'
  scope: resourceGroup(resourceGroupData.name)
  params: {
    accountName: uniqueString(resourceGroupData.id)
    containerName: 'testdata'
    tags: tags
  }
}

module storagePrivateEndpoint 'modules/privateendpoint.bicep' = {
  name: 'storageAccount-privateEndpoint'
  scope: resourceGroup(resourceGroupData.name)
  dependsOn: [
    storageAccount
  ]
  params: {
    privateEndpointName: '${storageAccount.outputs.name}-storageEndpoint'
    serviceResourceId: storageAccount.outputs.id
    resourceGroupNameNetwork: networkResourceGroupName
    vnetName: vnetName
    subnetName: 'azureServices'
    // dnsZoneId: resourceId(subscriptionId, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.core.windows.net' )
    dnsZoneName: 'privatelink.blob.core.windows.net'
    groupId: 'blob'
  }
}

// Virtual Machine
module vm 'modules/vm-win10.bicep' = {
  name: 'utilityVM'
  scope: resourceGroup(resourceGroupUtil.name)
  params: {
    vmName: '${uniqueString(resourceGroupUtil.id)}01'
    networkResourceGroupName: networkResourceGroupName
    vnetName: vnetName
    subnetName: 'utility'
    adminUserName: vmAdminUserName
    adminPassword: vmAdminPwd
  }
}

// Function App
module functionApp 'modules/functionapp.bicep' = {
  name: 'functionApp'
  dependsOn: [
    storageAccount
  ]
  scope: resourceGroup(resourceGroupApp.name)
  params: {
    name: uniqueString(resourceGroupApp.id)
    appInsightsKey: appInsights.outputs.key
    resourceGroupNameNetwork: networkResourceGroupName
    vnetName: vnetName
    subnetNameIntegration: 'funcintegration'
    subnetNamePrivateEndpoint: 'azureservices'
    workerRuntime: 'node'
    storageAccountNameData: storageAccount.outputs.name
    storageAccountIdData: storageAccount.outputs.id
    storageAccountApiVersionData: storageAccount.outputs.apiVersion
    appTags: tags
  }
}

// Data Factory
module adf 'modules/datafactory.bicep' = {
  name: 'adf'
  scope: resourceGroup(resourceGroupData.name)
  params: {
     adfName: uniqueString(resourceGroupData.id)
     actionGroupName: actionGroup.name
  }
}

module dataFactoryPrivateEndpoint 'modules/privateendpoint.bicep' = {
  name: 'datafactory-privateEndpoint'
  scope: resourceGroup(resourceGroupData.name)
  dependsOn: [
    adf
  ]
  params: {
    privateEndpointName: '${adf.outputs.name}-dataFactoryEndpoint'
    serviceResourceId: adf.outputs.id
    resourceGroupNameNetwork: networkResourceGroupName
    vnetName: vnetName
    subnetName: 'azureServices'
    dnsZoneName: 'privatelink.datafactory.azure.net'
    groupId: 'dataFactory'
  }
}

// Synapse SQL
module sqlSynapse 'modules/sqlpool.bicep' = {
  name: 'sql-dedicatedpool'
  scope: resourceGroup(resourceGroupData.name)
  dependsOn: [
    adf
  ]
  params: {
    serverName: '${uniqueString(resourceGroupData.id)}'
    sqlPoolName: 'testdb'
    sqlPoolSKU: 'DW100c'
    adminLoginName: sqlAdminLoginName
    adminLoginPwd: vmAdminPwd
    adminObjectId: sqlAdminObjectId
    resourceGroupNameNetwork: networkResourceGroupName
    vnetNamePrivateEndpoint: vnetName
    subnetNamePrivateEndpoint: 'azureServices'
    tags: tags
  }
}
