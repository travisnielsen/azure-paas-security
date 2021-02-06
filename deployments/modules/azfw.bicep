param prefix string
param hubId string
param utilSubnetCidr string
param actionGroupId string

resource publicIp 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: '${prefix}-azfw-ip'
  location: resourceGroup().location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
  }
}

resource fwl 'Microsoft.Network/azureFirewalls@2020-06-01' = {
  name: '${prefix}-azfw'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: '${prefix}-azfw-ipconf'
        properties: {
          subnet: {
            id: '${hubId}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    networkRuleCollections: [
      {
        name: 'test-collection'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 100
          rules: [
            {
              description: 'Allow outbound web traffic for util subnet'
              name: 'util-outbound-all'
              protocols: [
                'TCP'
              ]
              sourceAddresses: [
                utilSubnetCidr
              ]
              destinationAddresses: [
                '*'
              ]
              destinationPorts: [
                '80'
                '443'
              ]
            }
          ]
        }
      }

    ]
  }
}

// alerts
resource firewallHealth 'microsoft.insights/metricAlerts@2018-03-01' = {
  name: 'firewallHealth'
  location: 'global'
  properties: {
    description: 'Your firewall health is degraded'
    severity: 3
    enabled: true
    scopes: [
      resourceId('Microsoft.Network/azureFirewalls', fwl.name)
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          threshold: 90
          name: 'Metric1'
          metricNamespace: 'Microsoft.Network/azureFirewalls'
          metricName: 'FirewallHealth'
          dimensions: [
            {
              name: 'Status'
              operator: 'Include'
              values: [
                'Healthy'
              ]
            }
          ]
          operator: 'LessThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.Network/azureFirewalls'
    targetResourceRegion: 'centralus'
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
  dependsOn: [
    fwl
  ]
}

resource applicationRuleHitCount 'microsoft.insights/metricAlerts@2018-03-01' = {
  name: 'applicationRuleHitCount'
  location: 'global'
  properties: {
    description: 'Your firewall application rule count'
    severity: 3
    enabled: true
    scopes: [
      resourceId('Microsoft.Network/azureFirewalls', fwl.name)
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          threshold: 10
          name: 'Metric3'
          metricNamespace: 'Microsoft.Network/azureFirewalls'
          metricName: 'ApplicationRuleHit'
          dimensions: [
            {
              name: 'Status'
              operator: 'Include'
              values: [
                'Healthy'
              ]
            }
          ]
          operator: 'GreaterThan'
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.Network/azureFirewalls'
    targetResourceRegion: 'centralus'
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
  dependsOn: [
    fwl
  ]
}

resource networkRuleHitCount 'microsoft.insights/metricAlerts@2018-03-01' = {
  name: 'networkRuleHitCount'
  location: 'global'
  properties: {
    description: 'Your firewall network rule hit count alert'
    severity: 3
    enabled: true
    scopes: [
      resourceId('Microsoft.Network/azureFirewalls', fwl.name)
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          threshold: 500
          name: 'Metric2'
          metricNamespace: 'Microsoft.Network/azureFirewalls'
          metricName: 'NetworkRuleHit'
          dimensions: [
            {
              name: 'Status'
              operator: 'Include'
              values: [
                'Healthy'
              ]
            }
          ]
          operator: 'GreaterThan'
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.Network/azureFirewalls'
    targetResourceRegion: 'centralus'
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
  dependsOn: [
    fwl
  ]
}

output privateIp string = fwl.properties.ipConfigurations[0].properties.privateIPAddress