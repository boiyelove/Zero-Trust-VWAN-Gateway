targetScope = 'resourceGroup'

@description('Explicit opt-in because Virtual WAN and Firewall Premium are chargeable.')
param deployTopology bool = false

@minLength(3)
@maxLength(16)
param namePrefix string = 'ztvwan'

@description('Two validated secured-hub definitions.')
param hubs array = []

@description('Explicit HTTPS destinations. Wildcards are rejected by the preflight validator.')
param approvedEgressFqdns array = []

@secure()
@description('Key Vault secret resource ID for the enterprise TLS inspection CA certificate.')
param tlsInspectionCertificateSecretId string = ''

param logRetentionDays int = 30

resource virtualWan 'Microsoft.Network/virtualWans@2024-05-01' = if (deployTopology) {
  name: '${namePrefix}-wan'
  location: resourceGroup().location
  properties: {
    allowBranchToBranchTraffic: true
    disableVpnEncryption: false
    type: 'Standard'
  }
}

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (deployTopology) {
  name: '${namePrefix}-logs'
  location: resourceGroup().location
  properties: {
    retentionInDays: logRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource privateDns 'Microsoft.Network/privateDnsZones@2024-06-01' = if (deployTopology) {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
}

module securedHubs './modules/secured-hub.bicep' = [
  for (hub, index) in hubs: if (deployTopology) {
    name: 'secured-hub-${index}'
    params: {
      virtualWanId: virtualWan.id
      hub: hub
      approvedEgressFqdns: approvedEgressFqdns
      tlsInspectionCertificateSecretId: tlsInspectionCertificateSecretId
      logAnalyticsWorkspaceId: logs.id
      privateDnsZoneId: privateDns.id
    }
  }
]

output securedHubIds array = [
  for (hub, index) in hubs: deployTopology ? securedHubs[index]!.outputs.hubId : ''
]
