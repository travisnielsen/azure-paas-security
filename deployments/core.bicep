targetScope = 'subscription'

param environment string {
  allowed: [
    'dev'
    'uat'
    'prod'
  ]
}
param region string = 'centralus'
param appPrefix string
param tags object = {
  project: 'AzSecurePaaS'
  component: 'core'
}

// HUB VNET IP SETTINGS
param bastionSubnetAddressPrefix string = '10.10.0.128/25'  // 123 addresses - 10.10.0.128 - 10.10.0.255
param desktopSubnetAddressPrefix string = '10.10.1.0/25'    // 123 addresses - 10.10.1.0 - 10.10.1.127

// SPOKE VNET IP SETTINGS
param spokeVnetAddressSpace string = '10.20.0.0/20'
param devopsSubnetAddressPrefix string = '10.20.0.64/26'        // 59 addresses - 10.20.0.64 - 10.20.0.128
param azServicesSubnetAddressPrefix string = '10.20.1.0/24'     // 251 addresses - 10.20.1.0 - 10.20.1.255
param integrationSubnetAddressPrefix string = '10.20.2.0/25'    // 123 addresses - 10.20.2.0 - 10.20.2.127

// DESKTOP
param vmAdminUserName string = 'vmadmin'
param vmAdminPwd string {
  secure: true
}

// Network Watcher
param networkWatcherName string = 'NetworkWatcher_${environment}_centralus'

resource netrg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${appPrefix}-${environment}-network'
  location: region
}

resource desktoprg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${appPrefix}-${environment}-desktop'
  location: region
}

// Deploy Action Group for monitoring/alerting
module actionGroup 'modules/actionGroup.bicep' = {
  name: 'actionGroup'
  scope: resourceGroup(netrg.name)
  params: {
    actionGroupName: 'wbademo-${environment}-networkadmin'
    actionGroupShortName: 'wbademoadmin'
  }
}

module hubVnet 'modules/vnet.bicep' = {
  name: 'hub-${environment}-vnet'
  scope: resourceGroup(netrg.name)
  params: {
    vnetName: '${appPrefix}-${environment}-hub'
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
    ]
  }
}

module spokeVnet 'modules/vnet.bicep' = {
  name: 'spoke-${environment}-vnet'
  scope: resourceGroup(netrg.name)
  params: {
    vnetName: '${appPrefix}-${environment}-app'
    addressSpaces: [
      spokeVnetAddressSpace
    ]
    subnets: [
      {
        name: 'devops'
        properties: {
          addressPrefix: devopsSubnetAddressPrefix
          routeTable: {
            id: route.outputs.id
          }
          networkSecurityGroup: {
            id: devopsNsg.outputs.id
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
            id: azServicesNsg.outputs.id
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
            id: funcIntegrationNsg.outputs.id
          }
        }
      }
    ]
  }
}

// NSG for Desktop subnet (jump servers / user compute)
module desktopNsg 'modules/nsg.bicep' = {
  name: '${appPrefix}-${environment}-hub-desktop'
  scope: resourceGroup(netrg.name)
  params: {
    name: '${appPrefix}-${environment}-hub-desktop'
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
        name: 'deny-default'
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
      /* Internet egress will be forced through Azure Fireall. Deny at the NSG level supercedes UDR flow 
      {
        name: 'deny-internet'
        properties: {
          priority: 1000
          protocol: '*'
          access: 'Deny'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '*'
        }
      }
      */
    ]
  }
}

// NSG for Bastion subnet
module bastionNsg 'modules/nsg.bicep' = {
  name: '${appPrefix}-${environment}-hub-bastion'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    desktopNsg
  ]
  params: {
    name: '${appPrefix}-${environment}-hub-bastion'
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
          name: 'deny-internet'
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

// NSG for devops subnet (private build servers)
module devopsNsg 'modules/nsg.bicep' = {
  name: '${appPrefix}-${environment}-app-devops'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    bastionNsg
  ]
  params: {
    name: '${appPrefix}-${environment}-app-devops'
    networkWatcherName: networkWatcherName
    securityRules: [

      /* Internet egress will be forced through Azure Fireall. Deny at the NSG level supercedes UDR flow
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
      */

      {
        name: 'deny-internet'
        properties: {
          priority: 1000
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

// NSG for Azure Functions subnet
module funcIntegrationNsg 'modules/nsg.bicep' = {
  name: '${appPrefix}-${environment}-app-functions'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    devopsNsg
  ]
  params: {
    name: '${appPrefix}-${environment}-app-functions'
    networkWatcherName: networkWatcherName
    securityRules: [
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

      /* Internet egress will be forced through Azure Fireall. Deny at the NSG level supercedes UDR flow
      {
        name: 'deny-internet'
        properties: {
          priority: 1000
          protocol: '*'
          access: 'Deny'
          direction: 'Outbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      */
    ]
  }
}

// NSG for Azure services configured with Private Link
module azServicesNsg 'modules/nsg.bicep' = {
  name: '${appPrefix}-${environment}-app-azsvc'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    funcIntegrationNsg
  ]
  params: {
    name: '${appPrefix}-${environment}-app-azsvc'
    networkWatcherName: networkWatcherName
    securityRules: [
      {
        name: 'allow-devops-subnet'
        properties: {
          priority: 100
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: devopsSubnetAddressPrefix
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
        name: 'deny-internet'
        properties: {
          priority: 1000
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
module hubAzFw 'modules/azfw.bicep' = {
  name: 'hub-${environment}-azfw'
  scope: resourceGroup(netrg.name)
  params: {
    prefix: 'hub-${environment}'
    hubId: hubVnet.outputs.id
    desktopSubnetCidr: desktopSubnetAddressPrefix
    devopsSubnetCidr: devopsSubnetAddressPrefix
    actionGroupId: actionGroup.outputs.id
  }
}

// VNET peering
module HubToSpokePeering 'modules/peering.bicep' = {
  name: 'hub-to-spoke-peering'
  scope: resourceGroup(netrg.name)
  params: {
    localVnetName: hubVnet.outputs.name
    remoteVnetName: 'spoke'
    remoteVnetId: spokeVnet.outputs.id
  }
}

// VNET peering
module SpokeToHubPeering 'modules/peering.bicep' = {
  name: 'spoke-to-hub-peering'
  scope: resourceGroup(netrg.name)
  params: {
    localVnetName: spokeVnet.outputs.name
    remoteVnetName: 'hub'
    remoteVnetId: hubVnet.outputs.id
  }
}

// User Define Route (force egress traffic through hub firewall)
module route 'modules/udr.bicep' = {
  name: 'udr'
  scope: resourceGroup(netrg.name)
  params: {
    name: '${appPrefix}-${environment}-${region}-app'
    azFwlIp: hubAzFw.outputs.privateIp
  }
}

// Bastion
module bastion 'modules/bastion.bicep' = {
  name: 'hub-bastion'
  scope: resourceGroup(netrg.name)
  params: {
    name: '${uniqueString(netrg.id)}'
    subnetId: '${hubVnet.outputs.id}/subnets/AzureBastionSubnet'
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
    vnetName: spokeVnet.outputs.name
    vnetId: spokeVnet.outputs.id
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
    vnetName: spokeVnet.outputs.name
    vnetId: spokeVnet.outputs.id
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
    vnetName: spokeVnet.outputs.name
    vnetId: spokeVnet.outputs.id
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
    vnetName: spokeVnet.outputs.name
    vnetId: spokeVnet.outputs.id
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
    vnetName: spokeVnet.outputs.name
    vnetId: spokeVnet.outputs.id
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
    vnetName: spokeVnet.outputs.name
    vnetId: spokeVnet.outputs.id
    zoneName: 'privatelink.azure.com'
    autoRegistration: false
  }
}


// TODO: THIS IS A HACK - need to find a better way to apply the UDR to the desktop subnet
module applyUdrForDesktop 'modules/vnet.bicep' = {
  name: 'hub-vnet-applyDesktopUDR'
  scope: resourceGroup(netrg.name)
  dependsOn: [
    route
  ]
  params: {
    vnetName: '${appPrefix}-${environment}-hub'
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
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetAddressPrefix
        }
      }
      {
        name: 'desktop'
        properties: {
          addressPrefix: desktopSubnetAddressPrefix
          networkSecurityGroup: {
            id: desktopNsg.outputs.id
          }
          routeTable: {
            id: route.outputs.id
          }
        }
      }
    ]
  }
}

// Virtual Machine for application access via Bastion
module vm 'modules/vm-win10.bicep' = {
  name: 'desktop-vm'
  scope: resourceGroup(desktoprg.name)
  dependsOn: [
    applyUdrForDesktop
  ]
  params: {
    vmName: '${uniqueString(desktoprg.id)}${environment}01'
    networkResourceGroupName: netrg.name
    vnetName: '${appPrefix}-${environment}-hub'
    subnetName: 'desktop'
    adminUserName: vmAdminUserName
    adminPassword: vmAdminPwd
  }
}