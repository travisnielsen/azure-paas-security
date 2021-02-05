targetScope = 'subscription'
param region string = 'centralus'
param appPrefix string

// Virtual Machine (jump)
param vmAdminUserName string
param vmAdminPwd string {
  secure: true
}

param tags object

param sqlAdminLoginName string
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
}

// App Insights resource
module appInsights 'modules/appinsights.bicep' = {
  name: 'appInsights'
  scope: resourceGroup(resourceGroupApp.name)
  params: {
    name: uniqueString(resourceGroupApp.id)
    logAnalyticsId: logAnalytics.outputs.id
    tags: tags
  }
}

var storageAccountName = uniqueString(resourceGroupData.id)
var dataFactoryName = uniqueString(resourceGroupData.id)

module dataTier 'modules/datatier.bicep' = {
  name: 'dataTier'
  scope: resourceGroup(resourceGroupData.name)
  params: {
    storageAccountName: storageAccountName
    storageContainerName: 'testdata'
    adfName: uniqueString(resourceGroupData.id)
    tags: tags
  }

}

module storagePrivateEndpoint 'modules/privateendpoint.bicep' = {
  name: 'storageAccount-privateEndpoint'
  scope: resourceGroup(resourceGroupData.name)
  dependsOn: [
    dataTier
  ]
  params: {
    privateEndpointName: '${storageAccountName}-storageEndpoint'
    serviceResourceId: dataTier.outputs.storageAccountId
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

module dataFactoryPrivateEndpoint 'modules/privateendpoint.bicep' = {
  name: 'datafactory-privateEndpoint'
  scope: resourceGroup(resourceGroupData.name)
  dependsOn: [
    dataTier
  ]
  params: {
    privateEndpointName: '${dataFactoryName}-dataFactoryEndpoint'
    serviceResourceId: dataTier.outputs.dataFactoryId
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
    dataTier
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
