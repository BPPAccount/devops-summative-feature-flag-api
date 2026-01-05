param location string = 'uksouth'
param prefix string = 'devopssum'

@secure()
param adminToken string

param ghcrUsername string
@secure()
param ghcrToken string

// First deployment needs some image value; CD workflow will immediately update it.
param bootstrapImage string = 'ghcr.io/bppaccount/devops-summative-feature-flag-api:bootstrap'

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${prefix}-logs'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 7
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
          server: 'ghcr.io'
          username: ghcrUsername
          passwordSecretRef: 'ghcr-token'
        }
      ]
      secrets: [
        { name: 'ghcr-token', value: ghcrToken }
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

output appFqdn string = app.properties.configuration.ingress.fqdn
output appUrl string = 'https://${app.properties.configuration.ingress.fqdn}'
