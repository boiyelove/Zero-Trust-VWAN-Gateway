# Architecture and decisions

Two Standard Virtual WAN hubs live in distinct regions and each has its own
Firewall Premium next hop. Private and internet routing intent are enabled in
both hubs so east-west, branch, inter-hub, and egress traffic follows symmetric
inspection. Spokes have no default outbound access and learn a default route
only through their secured connection.

## Decisions

- **ADR-001:** both routing intents are mandatory in every hub. A partially
  secured hub is rejected.
- **ADR-002:** default deny is preserved. The baseline permits DNS to the Azure
  platform resolver and explicit HTTPS FQDNs only.
- **ADR-003:** approved HTTPS is TLS-inspected with an operator-owned CA stored
  in Key Vault. Exceptions require an owner, reason, and expiry.
- **ADR-004:** route state must be exported before change because removing
  routing intent does not restore the prior route table.

No custom hub route tables are created because they conflict with routing
intent prerequisites. Branch circuits, gateways, and production private DNS
catalogs remain environment-specific. Verify region support, quotas, API
versions, TLS compatibility, and asymmetric Private Endpoint paths before use.
