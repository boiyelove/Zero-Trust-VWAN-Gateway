# Test matrix

| Scenario | Expected result | Automated locally |
|---|---|---|
| Two distinct regions | accepted | Yes |
| Overlapping CIDRs | rejected | Yes |
| Standard firewall or alert-only IDPS | rejected | Yes |
| Missing private/internet intent | rejected | Yes |
| Wildcard egress | rejected | Yes |
| Expired TLS exception | rejected | Yes |
| Parameter render repeated | byte-identical | Yes |
| Spoke-to-spoke/branch path | Firewall in effective route | Azure integration |
| Unapproved HTTPS and east-west | denied and logged | Azure integration |
| TLS inspection and exception | expected certificate behavior | Azure integration |
| Region failure | documented convergence and application recovery | Azure drill |
| DNS/private endpoint symmetry | resolution and route correct | Azure integration |
| No workload public IP | policy query returns none | Azure integration |
| Teardown | resources absent and billing stopped | Azure integration |

Local validation does not prove Azure data-plane behavior, region failover,
certificate trust, policy compliance, quotas, or costs. Those gates require a
disposable Azure deployment and captured sanitized evidence.
