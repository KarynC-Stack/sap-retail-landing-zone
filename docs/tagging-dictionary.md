# Tagging dictionary (Q7)

| Key | Allowed values | Required on | Enforced by |
|-----|----------------|-------------|-------------|
| `ManagedBy` | `Kitstek` | All resources | Tag policy values; SCP `sr-workloads-required-tags` (EC2); enforcer Lambda adds if missing |
| `Client` | `SAP_Retail` | All resources | Same as ManagedBy |
| `Country` | `Kenya`, `Uganda`, `Shared` | All resources | Tag policy; SCP (EC2 in Workloads) |
| `Environment` | `Production`, `Non-Production`, `Shared` | All resources | Tag policy; SCP (EC2 in Workloads) |
| `aws-apn-id` | `<APN_ID>` | All resources | SCP `sr-root-require-apn-tag` (preventive) + enforcer Lambda (corrective) + tag policy |
| `Schedule` | `office-hours` | Optional (Non-Production EC2) | Instance scheduler opt-in |

All five standard keys are activated as cost allocation tags (`scripts/enable-org-features.ps1`, verify Q7.2).
The cost categories `Country` and `Environment` roll up spend by these tags, with account-based fallback rules.
