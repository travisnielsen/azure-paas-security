targetScope = 'subscription'

param region string = 'centralus'
param appPrefix string

// SPOKE VNET IP SETTINGS
param spokeVnetAddressSpace string = '10.20.0.0/20'
param bastionSubnetAddressPrefix string = '10.20.0.0/26'      // 64 addresses - 10.20.0.0 - 10.20.0.63
param utilSubnetAddressPrefix string = '10.20.0.64/26'        // 64 addresses - 10.20.0.64 - 10.20.0.128
param azServicesSubnetAddressPrefix string = '10.20.1.0/24'    // 256 addresses - 10.20.1.0 - 10.20.1.255
param integrationSubnetAddressPrefix string = '10.20.2.0/25'  // 128 addresses - 10.20.2.0 - 10.20.2.127

// Network Watcher
param networkWatcherName string = 'NetworkWatcher_centralus'

resource netrg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${appPrefix}-network'
  location: region
}

module hubVNET 'modules/vnet.bicep' = {
  name: 'hub-vnet'
  scope: resourceGroup(netrg.name)
  params: {
    vnetName: '${appPrefix}-${region}-hub'
    addressSpaces: [
      '10.10.0.0/20'
    ]
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.10.0.0/25'
        }
      }
    ]
  }
}

module spokeVNET 'modules/vnet.bicep' = {
  name: 'spoke-vnet'
  scope: resourceGroup(netrg.name)
  params: {
    vnetName: '${appPrefix}-${region}-app'
    addressSpaces: [
      spokeVnetAddressSpace
    ]
    subnets: [
      {
        // NOTE: UDR not allowed in a Bastion subnet
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetAddressPrefix
          /*
          networkSecurityGroup: {
            id: BastionNsg.outputs.id
          }
          */
        }
      }
      {
        name: 'utility'
        properties: {
          addressPrefix: utilSubnetAddressPrefix
          routeTable: {
            id: route.outputs.id
          }
          networkSecurityGroup: {
            id: UtilNsg.outputs.id
          }
        }
      }
      {
        name: 'azureservices'
        properties: {
          addressPrefix: azServicesSubnetAddressPrefix
          routeTable: {
            id: route.outputs.id
          }
          networkSecurityGroup: {
            id: AzureServicesNsg.outputs.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'funcintegration'
        properties: {
          addressPrefix: integrationSubnetAddressPrefix
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          routeTable: {
            id: route.outputs.id
          }
          networkSecurityGroup: {
            id: UtilNsg.outputs.id
          }
        }
      }
    ]
  }
}


// NSG for Utility subnet (jump servers)
module UtilNsg 'modules/nsg.bicep' = {
  name: '${appPrefix}-${region}-app-util'
  scope: resourceGroup(netrg.name)
  params: {
    name: '${appPrefix}-${region}-app-util'
    networkWatcherName: networkWatcherName
    securityRules: [
      {
        name: 'allow-bastion'
        properties: {
          priority: 100
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: bastionSubnetAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
        }
      }
      {
        name: 'deny-inbound-default'
        properties: {
          priority: 120
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// NSG for Bastion subnet
module BastionNsg 'modules/nsg.bicep' = {
  name: '${appPrefix}-${region}-app-bastion'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    UtilNsg
  ]
  params: {
    name: '${appPrefix}-${region}-app-bastion'
    networkWatcherName: networkWatcherName
    securityRules: [
        // SEE: https://docs.microsoft.com/en-us/azure/bastion/bastion-nsg#apply
        {
          name: 'bastion-ingress'
          properties: {
            priority: 100
            protocol: 'Tcp'
            access: 'Allow'
            direction: 'Inbound'
            sourceAddressPrefix: 'Internet'
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
            destinationPortRange: '443'
          }
        }
        {
          name: 'bastion-gatewaymgr'
          properties: {
            priority: 120
            protocol: 'Tcp'
            access: 'Allow'
            direction: 'Inbound'
            sourceAddressPrefix: 'GatewayManager'
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
            destinationPortRange: '443'
          }
        }
        {
          name: 'bastion-loadbalancer'
          properties: {
            priority: 140
            protocol: 'Tcp'
            access: 'Allow'
            direction: 'Inbound'
            sourceAddressPrefix: 'AzureLoadBalancer'
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
            destinationPortRange: '443'
          }
        }
        {
          name: 'allow-ssh-rdp-vnet'
          properties: {
            priority: 100
            protocol: '*'
            access: 'Allow'
            direction: 'Outbound'
            sourceAddressPrefix: '*'
            sourcePortRange: '*'
            destinationAddressPrefix: 'VirtualNetwork'
            destinationPortRanges: [
              '22'
              '3389'
            ]
          }
        }
        {
          name: 'allow-azure-dependencies'
          properties: {
            priority: 120
            protocol: '*'
            access: 'Allow'
            direction: 'Outbound'
            sourceAddressPrefix: '*'
            sourcePortRange: '*'
            destinationAddressPrefix: 'AzureCloud'
            destinationPortRange: '443'
          }
        }
        {
          name: 'deny-egress'
          properties: {
            priority: 140
            protocol: '*'
            access: 'Deny'
            direction: 'Outbound'
            sourceAddressPrefix: '*'
            sourcePortRange: '*'
            destinationAddressPrefix: 'Internet'
            destinationPortRange: '*'
          }
        }
    ]
  }
}

// NSG for Azure services configured with Private Link
module AzureServicesNsg 'modules/nsg.bicep' = {
  name: '${appPrefix}-${region}-app-azsvc'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    BastionNsg
  ]
  params: {
    name: '${appPrefix}-${region}-app-azsvc'
    networkWatcherName: networkWatcherName
    securityRules: [
      {
        name: 'allow-util-subnet'
        properties: {
          priority: 100
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: utilSubnetAddressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'deny-inbound-default'
        properties: {
          priority: 120
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'deny-outbound-internet'
        properties: {
          priority: 100
          protocol: '*'
          access: 'Deny'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// Hub firewall
module HubAzFw 'modules/azfw.bicep' = {
  name: 'hub-azfw'
  scope: resourceGroup(netrg.name)
  params: {
    prefix: 'hub'
    hubId: hubVNET.outputs.id
    utilSubnetCidr: utilSubnetAddressPrefix
  }
}

// VNET peering
module HubToSpokePeering 'modules/peering.bicep' = {
  name: 'hub-to-spoke-peering'
  scope: resourceGroup(netrg.name)
  params: {
    localVnetName: hubVNET.outputs.name
    remoteVnetName: 'spoke'
    remoteVnetId: spokeVNET.outputs.id
  }
}

// VNET peering
module SpokeToHubPeering 'modules/peering.bicep' = {
  name: 'spoke-to-hub-peering'
  scope: resourceGroup(netrg.name)
  params: {
    localVnetName: spokeVNET.outputs.name
    remoteVnetName: 'hub'
    remoteVnetId: hubVNET.outputs.id
  }
}

// User Define Route (force egress traffic through hub firewall)
module route 'modules/udr.bicep' = {
  name: 'spoke-udr'
  scope: resourceGroup(netrg.name)
  params: {
    name: '${appPrefix}-${region}-app'
    azFwlIp: HubAzFw.outputs.privateIp
  }
}

// Bastion
module bastion 'modules/bastion.bicep' = {
  name: 'spoke-bastion'
  scope: resourceGroup(netrg.name)
  params: {
    name: '${uniqueString(netrg.id)}'
    subnetId: '${spokeVNET.outputs.id}/subnets/AzureBastionSubnet'
  }
}

// Private DNS zone for Azure Web Sites (Functions and Web Apps)
module privateZoneAzureWebsites 'modules/dnszoneprivate.bicep' = {
  name: 'dns-private-azurewebsites'
  scope: resourceGroup(netrg.name)
  params: {
    zoneName: 'privatelink.azurewebsites.net'
  }
}

// Link the spoke VNet to the privatelink.azurewebsites.net private zone
module spokeVnetAzureWebsitesZoneLink 'modules/dnszonelink.bicep' = {
  name: 'dns-link-azurewebsites-spokevnet'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    privateZoneAzureWebsites
  ]
  params: {
    vnetName: spokeVNET.outputs.name
    vnetId: spokeVNET.outputs.id
    zoneName: 'privatelink.azurewebsites.net'
    autoRegistration: false
  }
}

// Private DNS zone for Azure Blob Storage (ADLS)
module privateZoneAzureBlobStorage 'modules/dnszoneprivate.bicep' = {
  name: 'dns-private-storage-blob'
  scope: resourceGroup(netrg.name)
  params: {
    zoneName: 'privatelink.blob.core.windows.net'
  }
}

// Link the spoke VNet to the privatelink.blob.core.windows.net private zone
module spokeVnetAzureBlobStorageZoneLink 'modules/dnszonelink.bicep' = {
  name: 'dns-link-blobstorage-spokevnet'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    privateZoneAzureBlobStorage
  ]
  params: {
    vnetName: spokeVNET.outputs.name
    vnetId: spokeVNET.outputs.id
    zoneName: 'privatelink.blob.core.windows.net'
    autoRegistration: false
  }
}

// Private DNS for Azure Data Factory
module privateZoneAzureDataFactory 'modules/dnszoneprivate.bicep' = {
  name: 'dns-private-datafactory'
  scope: resourceGroup(netrg.name)
  params: {
    zoneName: 'privatelink.datafactory.azure.net'
  }
}

// Link the spoke VNet to the privatelink.datafactory.azure.net private zone
module spokeVnetAzureDataFactoryZoneLink 'modules/dnszonelink.bicep' = {
  name: 'dns-link-datafactory-spokevnet'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    privateZoneAzureDataFactory
  ]
  params: {
    vnetName: spokeVNET.outputs.name
    vnetId: spokeVNET.outputs.id
    zoneName: 'privatelink.datafactory.azure.net'
    autoRegistration: false
  }
}

// Private DNS for Synapse SQL
module privateZoneSynapseSql 'modules/dnszoneprivate.bicep' = {
  name: 'dns-private-synapse-sql'
  scope: resourceGroup(netrg.name)
  params: {
    zoneName: 'privatelink.sql.azuresynapse.net'
  }
}

// Link the spoke VNet to the privatelink.sql.azuresynapse.net private zone
module spokeVnetSynapseSqlZoneLink 'modules/dnszonelink.bicep' = {
  name: 'dns-link-synapsesql-spokevnet'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    privateZoneSynapseSql
  ]
  params: {
    vnetName: spokeVNET.outputs.name
    vnetId: spokeVNET.outputs.id
    zoneName: 'privatelink.sql.azuresynapse.net'
    autoRegistration: false
  }
}

// Private DNS zone for SQL
module privateZoneSql 'modules/dnszoneprivate.bicep' = {
  name: 'dns-private-sql'
  scope: resourceGroup(netrg.name)
  params: {
    zoneName: 'privatelink.database.windows.net'
  }
}

// Link the spoke VNet to the privatelink.database.windows.net private zone
module spokeVnetSqlZoneLink 'modules/dnszonelink.bicep' = {
  name: 'dns-link-sql-spokevnet'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    privateZoneSql
  ]
  params: {
    vnetName: spokeVNET.outputs.name
    vnetId: spokeVNET.outputs.id
    zoneName: 'privatelink.database.windows.net'
    autoRegistration: false
  }
}

// Private DNS zone for other Azure services
module privateZoneAzure 'modules/dnszoneprivate.bicep' = {
  name: 'dns-private-azure'
  scope: resourceGroup(netrg.name)
  params: {
    zoneName: 'privatelink.azure.com'
  }
}


// Link the spoke VNet to the privatelink.azure.com private zone
// NOTE: See: https://stackoverflow.com/questions/64725413/azure-bastion-and-private-link-in-the-same-virtual-network-access-to-virtual-ma
// Must add CNAME record for 'management.privatelink.azure.com' that points to 'arm-frontdoor-prod.trafficmanager.net'
module frontdoorcname 'modules/dnscname.bicep' = {
  name: 'frontdoor-cname'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    privateZoneAzure
  ]
  params: {
    appName: 'management'
    dnsZone: 'privatelink.azure.com'
    alias: 'arm-frontdoor-prod.trafficmanager.net'
  }
}


module spokeVnetAzureZoneLink 'modules/dnszonelink.bicep' = {
  name: 'dns-link-azure-spokevnet'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    privateZoneAzure
  ]
  params: {
    vnetName: spokeVNET.outputs.name
    vnetId: spokeVNET.outputs.id
    zoneName: 'privatelink.azure.com'
    autoRegistration: false
  }
}

