// Deployment values for Zero-Trust-VWAN-Gateway (main.bicep).
// Values are synthetic and safe by default; review placeholders before what-if or deployment.
using './main.bicep'

// Controls whether this optional deployment path is enabled.
param deployTopology = false

// Defines deterministic naming for this example environment.
param namePrefix = 'ztvwan'

// Defines the reviewed network boundary for this environment.
param hubs = []

// Defines the reviewed network boundary for this environment.
param approvedEgressFqdns = []

// Reads sensitive deployment material from the environment instead of source control.
param tlsInspectionCertificateSecretId = ''

// Supplies the logRetentionDays input separately from the resource template.
param logRetentionDays = 30
