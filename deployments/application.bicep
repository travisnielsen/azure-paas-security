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
var sqlServerName = uniqueString(resourceGroupData.id)

module dataTier 'modules/datatier.bicep' = {
  name: 'dataTier'
  scope: resourceGroup(resourceGroupData.name)
  params: {
    storageAccountName: storageAccountName
    storageContainerName: 'testdata'
    adfName: dataFactoryName
    tags: tags
    vnetName: vnetName
    networkResourceGroupName: networkResourceGroupName
    sqlAdminLoginName: sqlAdminLoginName
    sqlAdminObjectId: sqlAdminObjectId
    sqlServerName: sqlServerName
    sqlAdminLoginPwd: vmAdminPwd
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