param privateEndpointName string
param subnetId string
param resourceId string
param dnsZoneId string

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: privateEndpointName
  location: resourceGroup().location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-connection'
        properties: {
          privateLinkServiceId: resourceId
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneConfig 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: '${privateEndpointName}/dnsgroupname'
  dependsOn: [
    privateEndpoint
  ]
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: dnsZoneId
        }
      }
    ]
  }
}

output id string = privateEndpoint.id