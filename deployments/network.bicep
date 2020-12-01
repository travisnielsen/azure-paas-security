targetScope = 'subscription'

param region string = 'centralus'

// SPOKE VNET IP SETTINGS
param spokeVnetAddressSpace string = '10.20.0.0/20'
param bastionSubnetAddressPrefix string = '10.20.0.0/26'      // 64 addresses - 10.20.0.0 - 10.20.0.63
param utilSubnetAddressPrefix string = '10.20.0.64/26'        // 64 addresses - 10.20.0.64 - 10.20.0.128
param azServicesSubnetAddressPrefix string = '10.20.1.0/24'    // 256 addresses - 10.20.1.0 - 10.20.1.255
param integrationSubnetAddressPrefix string = '10.20.2.0/25'  // 128 addresses - 10.20.2.0 - 10.20.2.127

// NSGs
param bastionNsgName string = 'spoke-nsg-bastion'
param utilNsgName string = 'spoke-nsg-util'
param azSvcNsgName string = 'spoke-nsg-azsvc'

// Storage
param storageAcctName string = 'trnielflowlogs'

// Log Analytics
param logAnalyticsName string = 'trnielnetanalytics'

// Network Watcher
param networkWatcherName string = 'NetworkWatcher_centralus'

resource netrg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: 'net-rg'
  location: region
}

module hubVNET 'modules/vnet.bicep' = {
  name: 'hub-vnet'
  scope: resourceGroup(netrg.name)
  params: {
    prefix: 'hub'
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
    prefix: 'spoke'
    addressSpaces: [
      spokeVnetAddressSpace
    ]
    subnets: [
      {
        // NOTE: UDR not allowed in a Bastion subnet
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetAddressPrefix
          networkSecurityGroup: {
            id: BastionNsg.outputs.id
          }
        }
      }
      {
        name: 'utility'
        properties: {
          addressPrefix: utilSubnetAddressPrefix
          networkSecurityGroup: {
            id: UtilNsg.outputs.id
          }
        }
      }
      {
        name: 'az-services'
        properties: {
          addressPrefix: azServicesSubnetAddressPrefix
          routeTable: {
            id: route.outputs.id
          }
          networkSecurityGroup: {
            id: AzureServicesNsg.outputs.id
          }
        }
      }
      {
        name: 'func-integration'
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
  name: utilNsgName
  scope: resourceGroup(netrg.name)
  params: {
    name: utilNsgName
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
          priority: 200
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

// NSG for Bastion subnet
module BastionNsg 'modules/nsg.bicep' = {
  name: bastionNsgName
  scope: resourceGroup(netrg.name)
  dependsOn: [
    UtilNsg
  ]
  params: {
    name: bastionNsgName
    networkWatcherName: networkWatcherName
    securityRules: [
        // SEE: https://docs.microsoft.com/en-us/azure/bastion/bastion-nsg#apply
        {
          name: 'bastion-ingress'
          properties: {
            priority: 120
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
            priority: 130
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
            priority: 110
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
            priority: 120
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
  name: azSvcNsgName
  scope: resourceGroup(netrg.name)
  dependsOn: [
    BastionNsg
  ]
  params: {
    name: azSvcNsgName
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
          priority: 200
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
    prefix: 'spoke'
    azFwlIp: HubAzFw.outputs.privateIp
  }
}

// Bastion
module bastion 'modules/bastion.bicep' = {
  name: 'spoke-bastion'
  scope: resourceGroup(netrg.name)
  params: {
    prefix: 'spoke'
    subnetId: '${spokeVNET.outputs.id}/subnets/AzureBastionSubnet'
  }
}

// Private DNS zone for Azure Web Sites (Functions and Web Apps)
module privateZoneAzureWebsites 'modules/dnszoneprivate.bicep' = {
  name: 'privatelink-azurewebsites-net'
  scope: resourceGroup(netrg.name)
  params: {
    zoneName: 'privatelink.azurewebsites.net'
  }
}

// Link the spoke VNet to the privatelink.azurewebsites.net private zone
module spokeVnetAzureWebsitesZoneLink 'modules/dnszonelink.bicep' = {
  name: 'spokevnet-zonelink-azurewebsites'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    privateZoneAzureWebsites
  ]
  params: {
    vnetName: spokeVNET.outputs.name
    vnetId: spokeVNET.outputs.id
    zoneName: 'privatelink.azurewebsites.net'
  }
}

// Private DNS zone for Azure Blob Storage (ADLS)
module privateZoneAzureBlobStorage 'modules/dnszoneprivate.bicep' = {
  name: 'privatelink-blob-core-windows-net'
  scope: resourceGroup(netrg.name)
  params: {
    zoneName: 'privatelink.blob.core.windows.net'
  }
}

// Link the spoke VNet to the privatelink.blob.core.windows.net private zone
module spokeVnetAzureBlobStorageZoneLink 'modules/dnszonelink.bicep' = {
  name: 'spokevnet-zonelink-blobstorage'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    privateZoneAzureBlobStorage
  ]
  params: {
    vnetName: spokeVNET.outputs.name
    vnetId: spokeVNET.outputs.id
    zoneName: 'privatelink.blob.core.windows.net'
  }
}