param serverName string
param sqlPoolName string
param sqlPoolSKU string
param adminLoginName string
param adminLoginPwd string
param adminObjectId string
param resourceGroupNameNetwork string
param vnetNamePrivateEndpoint string
param subnetNamePrivateEndpoint string
param tags object

var blocContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var sqlDefenderContainerName = 'defender'

resource sqlserver 'Microsoft.Sql/servers@2019-06-01-preview' = {
  name: serverName
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: adminLoginPwd
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
}

resource sqladmin 'Microsoft.Sql/servers/administrators@2019-06-01-preview' = {
  name: '${sqlserver.name}/ActiveDirectory'
  dependsOn: [
    sqlserver
  ]
  properties: {
    administratorType: 'ActiveDirectory'
    login: adminLoginName
    sid: adminObjectId
    tenantId: subscription().tenantId
  }

}

resource securityAlertsPolicy 'Microsoft.Sql/servers/securityAlertPolicies@2020-02-02-preview' = {
  name: '${sqlserver.name}/Default'
  dependsOn: [
    sqlserver
  ]
  properties: {
    state: 'Enabled'
  }
}

resource auditstorage 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: '${serverName}audit'
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
  tags: tags
}

resource defendercontainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${auditstorage.name}/default/${sqlDefenderContainerName}'
}

var containerSasProperties = {
  canonicalizedResource: '/blob/${auditstorage.name}/${sqlDefenderContainerName}'
  signedService: 'c'
  signedPermission: 'rw'
  signedExpiry: '2021-07-01T00:00:01Z'
}

resource roleassignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(blocContributorRoleId, resourceGroup().id)
  dependsOn: [
    sqlserver
    auditstorage
  ]
  scope: auditstorage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blocContributorRoleId)
    principalId: sqlserver.identity.principalId
    principalType: 'ServicePrincipal'
  }
} 

resource auditsettings 'Microsoft.Sql/servers/auditingSettings@2017-03-01-preview' = {
  name: '${sqlserver.name}/DefaultAuditSettings'
  dependsOn: [
    roleassignment
  ]
  properties: {
     state: 'Enabled'
     storageEndpoint: auditstorage.properties.primaryEndpoints.blob
     storageAccountSubscriptionId: subscription().subscriptionId
     isStorageSecondaryKeyInUse: false
  }
}

resource azuredefender 'Microsoft.Sql/servers/vulnerabilityAssessments@2018-06-01-preview' = {
  name: '${sqlserver.name}/DefaultAssesment'
  dependsOn: [
    roleassignment
    securityAlertsPolicy
  ]
  properties: {
    storageContainerPath: '${auditstorage.properties.primaryEndpoints.blob}defender'
    storageContainerSasKey: listServiceSas(auditstorage.name, '2018-02-01', containerSasProperties).serviceSasToken
    recurringScans: {
      emails: [
        'security@contoso.com'
      ]
      emailSubscriptionAdmins: true
      isEnabled: true
    }
  }
}

resource sqldb 'Microsoft.Sql/servers/databases@2020-08-01-preview' = {
  name: '${serverName}/${sqlPoolName}'
  location: resourceGroup().location
  dependsOn: [
    sqlserver
  ]
  sku: {
    name: sqlPoolSKU  // DW100c
    tier: 'DataWarehouse'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

module sqlPrivateEndpoint 'privateendpoint.bicep' = {
  name: '${sqlserver.name}-privateendpoint'
  dependsOn: [
    sqlserver
  ]
  params: {
    privateEndpointName: '${sqlserver.name}-sqlEndpoint'
    serviceResourceId: sqlserver.id
    dnsZoneName: 'privatelink.database.windows.net'
    resourceGroupNameNetwork: resourceGroupNameNetwork
    vnetName: vnetNamePrivateEndpoint
    subnetName: subnetNamePrivateEndpoint
    groupId: 'sqlServer'
  }
}