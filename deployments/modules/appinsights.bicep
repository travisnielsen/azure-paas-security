param name string
param logAnalyticsId string
param tags object
param actionGroupId string

var responseTime = 3

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: name
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: tags
}

resource serverExceptions 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'serverExceptions'
  location: 'global'
  properties: {
    description: 'send alerts for Server exceptions'
    severity: 4
    enabled: true
    scopes: [
      resourceId('Microsoft.Insights/components', appInsights.name)
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Metric1'
          dimensions: []
          metricName: 'exceptions/server'
          operator: 'GreaterThan'
          threshold: responseTime
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

resource failedRequests 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'failedRequests'
  location: 'global'
  properties: {
    description: 'send alerts for Failed Requests'
    severity: 4
    enabled: true
    scopes: [
      resourceId('Microsoft.Insights/components', appInsights.name)
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Metric2'
          dimensions: []
          metricName: 'requests/failed'
          operator: 'GreaterThanOrEqual'
          threshold: 1
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

resource serverResponseTime 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'serverResponseTime'
  location: 'global'
  properties: {
    description: 'response time alert'
    severity: 4
    enabled: true
    scopes: [
      resourceId('Microsoft.Insights/components', appInsights.name)
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Metric3'
          metricName: 'requests/duration'
          operator: 'GreaterThan'
          dimensions: []
          threshold: responseTime
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}

output id string = appInsights.id
output key string = appInsights.properties.InstrumentationKey
