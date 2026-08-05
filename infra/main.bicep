// Zero-Trust-VWAN-Gateway infrastructure template.
// Resource behavior stays in this file; deployment-time values are supplied by ./main.bicepparam.

targetScope = 'resourceGroup'

// Deployment inputs: values are explicit, reviewable, and environment-specific.

@description('Explicit opt-in because Virtual WAN and Firewall Premium are chargeable.')
param deployTopology bool = false

@minLength(3)
@maxLength(16)
param namePrefix string

@description('Two validated secured-hub definitions.')
param hubs array

@description('Explicit HTTPS destinations. Wildcards are rejected by the preflight validator.')
param approvedEgressFqdns array

@secure()
@description('Key Vault secret resource ID for the enterprise TLS inspection CA certificate.')
param tlsInspectionCertificateSecretId string

param logRetentionDays int

// Resource virtualWan: declares Microsoft.Network/virtualWans@2024-05-01 and its security settings.
resource virtualWan 'Microsoft.Network/virtualWans@2024-05-01' = if (deployTopology) {
  name: '${namePrefix}-wan'
  location: resourceGroup().location
  properties: {
    allowBranchToBranchTraffic: true
    disableVpnEncryption: false
    type: 'Standard'
  }
}

// Resource logs: declares Microsoft.OperationalInsights/workspaces@2023-09-01 and its security settings.
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

// Resource privateDns: declares Microsoft.Network/privateDnsZones@2024-06-01 and its security settings.
resource privateDns 'Microsoft.Network/privateDnsZones@2024-06-01' = if (deployTopology) {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
}

// Module securedHubs: composes ./modules/secured-hub.bicep with validated inputs.
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

// Deployment outputs: expose identifiers needed by operators and downstream automation.
output securedHubIds array = [for (hub, index) in hubs: deployTopology ? securedHubs[index]!.outputs.hubId : '']
