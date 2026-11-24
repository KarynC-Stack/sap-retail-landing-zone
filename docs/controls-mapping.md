# Security framework alignment (Q4, Q9)

The target is alignment with the **AWS Foundational Security Best Practices** and **CIS AWS Foundations Benchmark v3.0.0** standards, applied through Security Hub central configuration (policy `sr-lz-fsbp-cis`). This is a design mapping. What is actually deployed and what has been captured is recorded in `audit/matrix.md`; read that file for status before relying on any row below.

Scope of the Security Hub policy (design decision 23): the Security, Infrastructure, Workloads and Sandbox OUs. The management account has no Security Hub subscription and no AWS Config recorder, so it is **not** covered.

| Control area | CIS v3.0 ref | Implementation | Evidence file (`verify/q4-q6-q7-evidence.ps1`) |
|--------------|--------------|----------------|-------------------|
| Root user protected | 1.4-1.7 | SCP `root-protection` protects landing zone roles and denies leaving the organization | `g-scps-root.json` |
| MFA for humans | 1.10 | Identity Center MFA settings (`docs/runbooks/identity-center-settings.md`). Not captured by the script | none |
| No long-lived keys | 1.11-1.14 | Humans use Identity Center. No IAM users are created by this repo | `q3-permission-sets.json` |
| Least privilege | 1.15-1.17 | Five permission sets; Access Analyzer unused-access analyzer | `q3-permission-sets.json`, `q4-analyzer-unused.json` |
| CloudTrail everywhere | 3.1 | Control Tower organization trail | `q6-cloudtrail.json` |
| Log integrity | 3.2-3.3 | Object Lock archive and SCP `log-archive-protection`. The archive is **not deployed** (design decision 14) | `q6-archive-object-lock.json` (expected to fail until deployed) |
| Config everywhere | 3.3 | Control Tower Config baseline in enrolled accounts. Not the management account | `q6-controltower.json` |
| Threat detection | n/a (FSBP GuardDuty.1) | GuardDuty organization configuration from Security Tooling | `q4-guardduty-org-config.json`, `q4-guardduty-members.json` |
| Findings alerting | n/a | Security Hub CRITICAL/HIGH findings to an SNS email topic. The subscription must be confirmed by the recipient | `q4-findings-rule.json`, `q4-findings-subscriptions.json` |

## Regulatory context
- **Kenya** (CBK prudential guidelines, IRA): data residency in eu-west-1 under the `region-kenya` SCP. Country-scoped OUs support separate reporting.
- **Uganda** (Bank of Uganda): OUs only, no accounts. The `region-uganda-deferred` SCP restricts the OU to eu-west-1 (docs/design-decisions.md).
- Log retention figures in earlier drafts of this file (48 months) are **not** implemented. Control Tower keeps logs 365 days and access logs 3650 days (design decision 13).

This is an alignment mapping, not a certification. Formal compliance assessment is outside the landing zone scope.
