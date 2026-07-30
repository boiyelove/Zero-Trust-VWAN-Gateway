# Threat model

| Threat | Control | Evidence | Residual risk |
|---|---|---|---|
| East-west bypasses inspection | Private routing intent in both hubs | Template assertions; effective routes in Azure | Unsupported asymmetric topology |
| Internet bypasses firewall | Internet intent and connection internet security | Template assertion | Workload-specific UDR misuse |
| Broad egress rule | Exact FQDN validator; no wildcard | Negative unit test | Destination compromise |
| Encrypted traffic hides payload | Premium TLS termination | Policy assertion | Pinned/mTLS applications need exceptions |
| Malicious/expired exception | Owner, justification, expiry validation | Negative unit test | Manual renewal approval quality |
| Route change causes outage | Pre-change snapshot and staged rollout | Runbook | Routing-intent rollback is not automatic |
| Firewall policy tampering | CODEOWNERS, CI scan, diagnostic logs | Repository test | Subscription-owner compromise |
| CIDR collision | canonical non-overlap validation | Negative unit test | External branch prefixes not supplied |

Firewall logs can contain sensitive network metadata. Restrict Log Analytics
access, set retention deliberately, and export evidence without payload data.
