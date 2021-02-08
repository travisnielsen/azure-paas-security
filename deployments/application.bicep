targetScope = 'subscription'
param region string = 'centralus'
param appPrefix string
param environment string {
  allowed: [
    'dev'
    'uat'
    'prod'
  ]
}

// Virtual Machine (jump)
param vmAdminUserName string
param vmAdminPwd string {
  secure: true
}

param tags object = {
  project: 'AzSecurePaaS'
}

param sqlAdminLoginName string
param sqlAdminObjectId string

// VNet integration
var subscriptionId = subscription().subscriptionId
var networkResourceGroupName = '${appPrefix}-${environment}-network'
var vnetName = '${appPrefix}-${environment}-${region}-app'

/*
var storageAccountName = concat(uniqueString(resourceGroupData.id), environment)
var dataFactoryName = concat(uniqueString(resourceGroupData.id), environment)
var sqlServerName = concat(uniqueString(resourceGroupData.id), environment)
*/

resource resourceGroupUtil 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${appPrefix}-${environment}-util'
  location: region
}

resource resourceGroupData 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${appPrefix}-${environment}-data'
  location: region
}

resource resourceGroupApp 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${appPrefix}-${environment}-app'
  location: region
}

// Log Analytics resource
module logAnalytics 'modules/loganalytics.bicep' = {
  name: 'logAnalytics'
  scope: resourceGroup(resourceGroupApp.name)
  params: {
    name: concat(uniqueString(resourceGroupApp.id), environment)
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
    actionGroupName: 'wbademo-${environment}-appadmin'
    actionGroupShortName: 'wbademoadmin'
  }
}

// App Insights resource
module appInsights 'modules/appinsights.bicep' = {
  name: 'appInsights'
  scope: resourceGroup(resourceGroupApp.name)
  params: {
    name: concat(uniqueString(resourceGroupApp.id), environment)
    logAnalyticsId: logAnalytics.outputs.id
    tags: tags
  }
}

/*
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
    sqlDatabaseName: 'AdventureWorksLT'
    sqlDatabaseSKU: 'DW100c'
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}
*/

// Virtual Machine
module vm 'modules/vm-win10.bicep' = {
  name: 'utilityVM'
  scope: resourceGroup(resourceGroupUtil.name)
  params: {
    vmName: '${concat(uniqueString(resourceGroupUtil.id), environment)}01'
    networkResourceGroupName: networkResourceGroupName
    vnetName: vnetName
    subnetName: 'utility'
    adminUserName: vmAdminUserName
    adminPassword: vmAdminPwd
  }
}
