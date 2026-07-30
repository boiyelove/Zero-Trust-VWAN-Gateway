param virtualWanId string
param hub object
param approvedEgressFqdns array
param tlsInspectionCertificateSecretId string
param logAnalyticsWorkspaceId string
param privateDnsZoneId string

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: '${hub.name}-policy'
  location: hub.location
  sku: {
    tier: 'Premium'
  }
  properties: {
    dnsSettings: {
      enableProxy: true
    }
    intrusionDetection: {
      mode: 'Deny'
    }
    threatIntelMode: 'Deny'
    transportSecurity: {
      certificateAuthority: {
        keyVaultSecretId: tlsInspectionCertificateSecretId
        name: 'enterprise-tls-inspection-ca'
      }
    }
  }
}

resource baselineRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: firewallPolicy
  name: 'explicit-baseline'
  properties: {
    priority: 100
    ruleCollections: [
      {
        name: 'allow-approved-https'
        priority: 100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'approved-tls-egress'
            ruleType: 'ApplicationRule'
            sourceAddresses: [
              hub.spokePrefix
            ]
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: approvedEgressFqdns
            terminateTLS: true
          }
        ]
      }
      {
        name: 'allow-platform-dns'
        priority: 200
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'azure-dns'
            ruleType: 'NetworkRule'
            sourceAddresses: [
              hub.spokePrefix
            ]
            destinationAddresses: [
              '168.63.129.16'
            ]
            destinationPorts: [
              '53'
            ]
            ipProtocols: [
              'TCP'
              'UDP'
            ]
          }
        ]
      }
    ]
  }
}

resource virtualHub 'Microsoft.Network/virtualHubs@2024-05-01' = {
  name: hub.name
  location: hub.location
  properties: {
    addressPrefix: hub.addressPrefix
    hubRoutingPreference: 'ASPath'
    sku: 'Standard'
    virtualRouterAsn: 65515
    virtualRouterAutoScaleConfiguration: {
      minCapacity: 2
    }
    virtualWan: {
      id: virtualWanId
    }
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: '${hub.name}-firewall'
  location: hub.location
  properties: {
    firewallPolicy: {
      id: firewallPolicy.id
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    sku: {
      name: 'AZFW_Hub'
      tier: 'Premium'
    }
    virtualHub: {
      id: virtualHub.id
    }
  }
  dependsOn: [
    baselineRules
  ]
}

resource routingIntent 'Microsoft.Network/virtualHubs/routingIntent@2024-05-01' = {
  parent: virtualHub
  name: 'default'
  properties: {
    routingPolicies: [
      {
        destinations: [
          '0.0.0.0/0'
        ]
        name: 'InternetTraffic'
        nextHop: firewall.id
      }
      {
        destinations: [
          '10.0.0.0/8'
          '172.16.0.0/12'
          '192.168.0.0/16'
        ]
        name: 'PrivateTraffic'
        nextHop: firewall.id
      }
    ]
  }
}

resource spoke 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${hub.name}-isolated-spoke'
  location: hub.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hub.spokePrefix
      ]
    }
    dhcpOptions: {
      dnsServers: []
    }
    subnets: [
      {
        name: 'workload'
        properties: {
          addressPrefix: cidrSubnet(hub.spokePrefix, 2, 0)
          defaultOutboundAccess: false
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-05-01' = {
  parent: virtualHub
  name: '${hub.name}-spoke'
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: false
    enableInternetSecurity: true
    remoteVirtualNetwork: {
      id: spoke.id
    }
  }
  dependsOn: [
    routingIntent
  ]
}

resource dnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: '${last(split(privateDnsZoneId, '/'))}/${hub.name}-spoke'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: spoke.id
    }
  }
}

resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: firewall
  name: 'central-logs'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output hubId string = virtualHub.id
