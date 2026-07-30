# Operations and rollback runbook

## Before change

1. Export every hub route table, routing intent, connection, gateway, learned
   route, and firewall policy; hash and timestamp the snapshot.
2. Validate all branch, spoke, Private Endpoint, and non-RFC1918 prefixes.
3. Confirm Firewall Premium and certificate capacity, region quotas, DNS
   behavior, budget alerts, and an out-of-band administration path.
4. Run local validation and Bicep `what-if` against a disposable group.

## Rollout and SLO

Deploy one region, verify effective RFC1918 and default routes, DNS, approved
egress, explicit denial, firewall logs, and connection health, then deploy the
second. Target 99.99% transit availability, zero uninspected scoped flows, route
convergence within the platform-agreed window, and log ingestion under five
minutes. Alert on firewall health/capacity, SNAT exhaustion, drops, IDPS alerts,
route count, connection state, and logging gaps.

## Failure and rollback

Freeze changes and preserve telemetry. Do not simply delete routing intent:
prior static route configuration is not restored automatically. Remove intent
only under an approved sequence, then reapply the exported connection and route
state, validate symmetric paths, and document variance. Certificate failure
uses an approved short-lived exception or policy rollback, never `terminateTLS`
removal across all destinations.

Teardown disconnects workloads and branches first, exports evidence, removes
hub connections, then deletes the disposable resource group after approval.
