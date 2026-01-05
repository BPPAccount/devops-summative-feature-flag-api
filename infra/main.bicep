param location string = 'uksouth'
param prefix string = 'devopssum'
@secure()
param adminToken string

// Use a public placeholder image for the very first bootstrap.
// Your pipeline will later update this to your built image.
param bootstrapImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

var acrName = toLower('${prefix}acr${uniqueString(resourceGroup().id)}')

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${prefix}-logs'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: true
  }
}

resource env 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${prefix}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
  }
}

var acrCreds = acr.listCredentials()
var acrUser = acrCreds.username
var acrPass = acrCreds.passwords[0].value
var acrServer = acr.properties.loginServer

resource app 'Microsoft.App/containerApps@2023-05-01' = {
  name: '${prefix}-api'
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
      }
      registries: [
        {
          server: acrServer
          username: acrUser
          passwordSecretRef: 'acr-pwd'
        }
      ]
      secrets: [
        { name: 'acr-pwd', value: acrPass }
        { name: 'admin-token', value: adminToken }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: bootstrapImage
          env: [
            { name: 'ADMIN_TOKEN', secretRef: 'admin-token' }
            { name: 'APP_VERSION', value: 'bootstrap' }
            { name: 'COMMIT_SHA', value: 'bootstrap' }
          ]
        }
      ]
      scale: { minReplicas: 0, maxReplicas: 1 }
    }
  }
}

output acrLoginServer string = acrServer
output acrNameOut string = acr.name
output appFqdn string = app.properties.configuration.ingress.fqdn
output appUrl string = 'https://${app.properties.configuration.ingress.fqdn}'
