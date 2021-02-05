param dataFactoryName string {
  metadata: {
    description: 'Name of the data factory. Name must be globally unique'
  }
}
param actionGroupName string {
  metadata: {
    description: 'Action group name. Must be unique within the resource group'
  }
}

resource whenadfactivityfailed 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'whenadfactivityfailed'
  location: 'global'
  properties: {
    actions: [
      {
        actionGroupId: resourceId('Microsoft.Insights/actionGroups', actionGroupName)
      }
    ]
    autoMitigate: true
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: []
          metricName: 'ActivityFailedRuns'
          metricNamespace: 'Microsoft.DataFactory/factories'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 1
          timeAggregation: 'Total'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'send alert when adf activity failed'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      resourceId('Microsoft.DataFactory/factories', dataFactoryName)
    ]
    severity: 4
    targetResourceType: 'Microsoft.DataFactory/factories'
    windowSize: 'PT1M'
  }
  dependsOn: [
    resourceId('Microsoft.DataFactory/factories', dataFactoryName)
  ]
}

resource whenadfpipelinefailed 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'whenadfpipelinefailed'
  location: 'global'
  properties: {
    actions: [
      {
        actionGroupId: resourceId('Microsoft.Insights/actionGroups', actionGroupName)
      }
    ]
    autoMitigate: true
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: []
          metricName: 'PipelineFailedRuns'
          metricNamespace: 'Microsoft.DataFactory/factories'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 1
          timeAggregation: 'Total'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'send alert when adf pipeline is failed'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      resourceId('Microsoft.DataFactory/factories', dataFactoryName)
    ]
    severity: 4
    targetResourceType: 'Microsoft.DataFactory/factories'
    windowSize: 'PT1M'
  }
  dependsOn: [
    resourceId('Microsoft.DataFactory/factories', dataFactoryName)
  ]
}

resource whenadftriggerfailed 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'whenadftriggerfailed'
  location: 'global'
  properties: {
    actions: [
      {
        actionGroupId: resourceId('Microsoft.Insights/actionGroups', actionGroupName)
      }
    ]
    autoMitigate: true
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: []
          metricName: 'TriggerFailedRuns'
          metricNamespace: 'Microsoft.DataFactory/factories'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 1
          timeAggregation: 'Total'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'send alert when adf trigger failed'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      resourceId('Microsoft.DataFactory/factories', dataFactoryName)
    ]
    severity: 4
    targetResourceType: 'Microsoft.DataFactory/factories'
    windowSize: 'PT1M'
  }
  dependsOn: [
    resourceId('Microsoft.DataFactory/factories', dataFactoryName)
  ]
}