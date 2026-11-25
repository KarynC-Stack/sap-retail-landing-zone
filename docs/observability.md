# Observability and monitoring (Q6)

What is collected, where it goes, what raises an alert, and who receives it.

## Log collection

| Source | Destination | Mechanism | Retention |
|---|---|---|---|
| API activity, every account | Control Tower log bucket in the Log Archive account, prefix `<ORGANIZATION_ID>/` | Control Tower organization CloudTrail (`aws-controltower-BaselineCloudTrail`), multi-Region, log file validation on | 365 days |
| API activity, searchable copy | CloudWatch Logs group `aws-controltower/CloudTrailLogs-<CT_BUCKET_SUFFIX>` in the management account | Control Tower | Control Tower default |
| Resource configuration history | Control Tower Config bucket in the Log Archive account | AWS Config recorder per enrolled account | 365 days |
| S3 access logs | Access-log bucket in the Log Archive account | Control Tower | 3650 days |
| DNS queries | CloudWatch Logs in the workload account | `Route53Resolver::ResolverQueryLoggingConfig` in `templates/06-network/workload-vpc.yaml` | Set per workload. Not deployed |
| Write-once archive | Object Lock bucket, GOVERNANCE mode | S3 replication from the Control Tower bucket, `templates/05-logging/log-archive.yaml` | 365 days Standard, then Glacier to 1460 days. **Not deployed** (design decisions 14 and 18) |

Retention numbers are Control Tower's and are read back in `audit/evidence/<timestamp>/q6-controltower.json`. The management account has no Config recorder: Control Tower does not create one there (design decision 23).

## Aggregation

| What | Where | Evidence file |
|---|---|---|
| Security Hub findings, all accounts | Security Tooling account, central configuration, policy `sr-lz-fsbp-cis` on the Security, Infrastructure, Workloads and Sandbox OUs | `q4-securityhub-org-config.json`, `q4-securityhub-associations.json` |
| GuardDuty findings, all accounts | Security Tooling account as delegated administrator | `q4-guardduty-members.json` |
| Config configuration items, all accounts | `aws-controltower-ConfigAggregatorForOrganization` in the Security Tooling account, all Regions | `q6-config-aggregator.json` |
| Access Analyzer findings | Two organization-level analyzers in the Security Tooling account | `q4-analyzer-org.json`, `q4-analyzer-unused.json` |

Cross-Region finding aggregation in Security Hub is deliberately off (`NO_REGIONS`): the organization operates in eu-west-1 only, and linking all Regions made the configuration policy fail (design decision 23).

## Alerting

| Signal | Route | Recipient | State |
|---|---|---|---|
| Security Hub findings, CRITICAL and HIGH | EventBridge rule `sr-lz-securityhub-critical-high` to SNS `sr-lz-security-findings` in the Security Tooling account | `security-alerts@example.com` | Deployed; subscription confirmed |
| Root account usage, console sign-in without MFA, break-glass assumed, IAM policy change, CloudTrail change, organization change, access-denied volume | CloudWatch alarms over the organization trail to SNS `sr-lz-operations-alerts` in the management account | `security-alerts@example.com` | **Template written, not deployed.** `templates/08-observability/security-monitoring.yaml` |
| Budget at 80 per cent of the monthly limit | AWS Budgets notification | `security-alerts@example.com` | Deployed |
| Cost anomaly at or above USD 50 | Cost anomaly subscription `sr-lz-anomaly-alerts`, daily | `security-alerts@example.com` | Deployed; subscriber confirmed |
| VPN tunnel down | CloudWatch alarm on `TunnelState` in the workload account | Topic passed in at deploy time | Template only; no VPN deployed |

Every SNS email subscription needs the recipient to click a confirmation link. An unconfirmed subscription silently drops messages, so `verify/q4-q6-q7-evidence.ps1` captures subscription state and the matrix records it.

## Dashboard

`sr-lz-governance` in the management account, created by the observability stack: privileged access, control-plane changes, access-denied volume, and the state of all seven governance alarms on one screen.

## What is not in place

- **No alert has been tested end to end.** `docs/runbooks/alert-test.md` is the procedure. Until it is run and recorded, delivery is unproven even though the wiring is in place.
- **No application or workload monitoring.** There are no workloads in this organization. The live Kenya SAP estate is monitored separately and is not covered here.
- **No operational metrics dashboard** (CPU, memory, disk) because there are no instances.

## Related files

- `templates/08-observability/security-monitoring.yaml` — metric filters, alarms, dashboard, operations topic
- `templates/04-security/security-tooling.yaml` — findings rule and topic
- `docs/runbooks/alert-test.md` — how to prove an alert arrives
- `verify/q4-q6-q7-evidence.ps1` — read-only capture of the above
