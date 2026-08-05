// Deployment values for Zero-Trust-VWAN-Gateway (secured-hub.bicep).
// Values are synthetic and safe by default; review placeholders before what-if or deployment.
using './secured-hub.bicep'

// Supplies the virtualWanId input separately from the resource template.
param virtualWanId = '/subscriptions/00000000-0000-4000-8000-000000000001/resourceGroups/rg-network/providers/Microsoft.Network/virtualWans/vwan-example'

// Defines the reviewed network boundary for this environment.
param hub = {
  name: 'hub-dev'
  location: 'westeurope'
  addressPrefix: '10.42.0.0/23'
}

// Defines the reviewed network boundary for this environment.
param approvedEgressFqdns = [
  'example.com'
]

// Reads sensitive deployment material from the environment instead of source control.
param tlsInspectionCertificateSecretId = '/subscriptions/00000000-0000-4000-8000-000000000001/resourceGroups/rg-security/providers/Microsoft.KeyVault/vaults/kv-example/secrets/tls-inspection'

// Supplies the logAnalyticsWorkspaceId input separately from the resource template.
param logAnalyticsWorkspaceId = '/subscriptions/00000000-0000-4000-8000-000000000001/resourceGroups/rg-observability/providers/Microsoft.OperationalInsights/workspaces/law-example'

// Defines the reviewed network boundary for this environment.
param privateDnsZoneId = '/subscriptions/00000000-0000-4000-8000-000000000001/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/example.internal'
