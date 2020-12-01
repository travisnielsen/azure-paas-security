param location string = resourceGroup().location
param functionRuntime string = 'dotnet'

param appNamePrefix string = uniqueString(resourceGroup().id)

// VNet integration
param subscriptionId string = 'cecea5c9-0754-4a7f-b5a9-46ae68dcafd3'
param networkRGName string = 'net-rg'
param vnetName string = 'spoke-vnet'
param subnetNameIntegration string = 'func-integration'
param subnetNamePrivEndpoint string = 'az-services'

// Services included in deployment
var functionAppName = '${appNamePrefix}-functionapp'
var appServiceName = '${appNamePrefix}-appservice'
var logAnalyticsName = '${appNamePrefix}-loganalytics'
var appInsightsName = '${appNamePrefix}-appinsights'
var storageAccountNameFunc = format('{0}func', replace(appNamePrefix, '-', ''))
var storageAccountNameData = format('{0}data', replace(appNamePrefix, '-', ''))
param storageAccountDataContainerName string = 'input'

var appTags = {
  AppID: 'myfunc'
  AppName: 'My Function App'
}

// Storage Account for the Function App
// TODO: This should be temporary to support setup only. Add automation for this: https://docs.microsoft.com/en-us/azure/azure-functions/functions-networking-options#restrict-your-storage-account-to-a-virtual-network-preview
resource storageAccountFunc 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountNameFunc
  location: location
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
  tags: appTags
}

// Log Analytics resource
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
  tags: appTags
}

// App Insights resource
resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: appTags
}

// App Service
resource appService 'Microsoft.Web/serverFarms@2020-06-01' = {
  name: appServiceName
  location: location
  kind: 'elastic'
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  properties: {
    maximumElasticWorkerCount: 20
  }
  tags: appTags
}

// Function App
resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${functionAppName}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${functionAppName}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
    ]
    serverFarmId: appService.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsights.properties.InstrumentationKey}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionRuntime
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~12'
        } 
      ]
    }
    httpsOnly: true
  }
  tags: appTags
}

// Function Network Config
resource functionNetworkConfig 'Microsoft.Web/sites/networkConfig@2020-06-01' = {
  name: '${functionApp.name}/virtualNetwork'
  dependsOn: [
    functionApp
  ]
  properties: {
    subnetResourceId: resourceId(subscriptionId, networkRGName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetNameIntegration )
  }
}

module functionPrivateEndpoint 'modules/privateendpoint.bicep' = {
  name: 'function-privendpoint'
  dependsOn: [
    functionApp
  ]
  params: {
    privateEndpointName: '${functionApp.name}-privendpoint'
    resourceId: functionApp.id
    subnetId: resourceId(subscriptionId, networkRGName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetNamePrivEndpoint )
    dnsZoneId: resourceId(subscriptionId, networkRGName, 'Microsoft.Network/privateDnsZones', 'privatelink.azurewebsites.net' )
    groupId: 'sites'
  }
}

// Function App Config
/*
resource functionAppConfig 'Microsoft.Web/sites/config@2020-06-01' = {
  name: '${functionApp.name}/web'
  properties: {
    numberOfWorkers: -1
    defaultDocuments: [
      'Default.htm'
      'Default.html'
      'Default.asp'
      'index.htm'
      'index.html'
      'iisstart.htm'
      'default.aspx'
      'index.php'
      'hostingstart.html'
    ]
    netFrameworkVersion: 'v4.0'
    phpVersion: '5.6'
    requestTracingEnabled: false
    remoteDebuggingEnabled: false
    httpLoggingEnabled: false
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: false
    publishingUsername: '$${functionAppName}'
    azureStorageAccounts: {}
    scmType: 'None'
    use32BitWorkerProcess: true
    webSocketsEnabled: false
    alwaysOn: false
    managedPipelineMode: 'Integrated'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true
      }
    ]
    loadBalancing: 'LeastRequests'
    experiments: {
      rampUpRules: []
    }
    autoHealEnabled: false
    cors: {
      allowedOrigins: [
        'https://functions.azure.com'
        'https://functions-staging.azure.com'
        'https://functions-next.azure.com'
      ]
      supportCredentials: false
    }
    localMySqlEnabled: false
    ipSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: true
    minTlsVersion: '1.2'
    ftpsState: 'AllAllowed'
    PreWarmedInstanceCount: 0
  }
  tags: appTags
}
*/

// Function App Binding
/*
resource functionAppBinding 'Microsoft.Web/sites/hostNameBindings@2020-06-01' = {
  name: '${functionApp.name}/${functionApp.name}.azurewebsites.net'
  properties: {
    siteName: functionApp.name
    hostNameType: 'Verified'
  }
}
*/

// Storage account for data
resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountNameData
  location: location
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
  tags: appTags
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-06-01' = {
  name: '${storageAccount.name}/default/${storageAccountDataContainerName}'
}

module adslsPrivateEndpoint 'modules/privateendpoint.bicep' = {
  name: 'function-privendpoint'
  dependsOn: [
    storageAccount
  ]
  params: {
    privateEndpointName: '${storageAccount.name}-privendpoint'
    resourceId: storageAccount.id
    subnetId: resourceId(subscriptionId, networkRGName, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetNamePrivEndpoint )
    dnsZoneId: resourceId(subscriptionId, networkRGName, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.core.windows.net' )
    groupId: 'blob'
  }
}