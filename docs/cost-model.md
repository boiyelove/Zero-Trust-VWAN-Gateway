# Cost model

The dominant fixed costs are two Virtual WAN hubs and two Azure Firewall Premium
instances. Variable costs include firewall data processing, hub connection and
gateway units, inter-region transfer, logs, public IPs used by secured-hub
firewalls, DNS, and optional branch gateways.

Price both selected regions immediately before deployment. Set subscription and
resource-group budgets, cap log retention, measure expected GB/hour by flow,
and load-test SNAT/IDPS capacity. The sample deploys no gateways or workloads
and defaults `deployTopology=false`, but an opted-in deployment is still
materially chargeable.
