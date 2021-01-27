param serverName string
param sqlPoolName string
param sqlPoolSKU string
param adminLogin string
param adminPwd string
param resourceGroupNameNetwork string
param vnetNamePrivateEndpoint string
param subnetNamePrivateEndpoint string

resource sqlserver 'Microsoft.Sql/servers@2019-06-01-preview' = {
  name: serverName
  location: resourceGroup().location
  properties: {
   administratorLogin: adminLogin
   administratorLoginPassword: adminPwd
   version: '12.0'
   minimalTlsVersion: '1.2'
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