# Runbook: end-to-end alert test (Q6; Delivery Kit Phase 2 topic 6)

Run after phase 5, then quarterly. Record the results below. The audit asks whether alerting has been validated end to end.

| # | Alert | How to trigger | Expected recipient |
|---|-------|----------------|--------------------|
| 1 | GuardDuty high severity | Security Tooling: `aws guardduty create-sample-findings --detector-id <id> --finding-types Backdoor:EC2/C&CActivity.B!DNS` | sr-lz-security-findings email |
| 2 | Security Hub critical | Import a test finding with severity CRITICAL via `batch-import-findings` | sr-lz-security-findings email |
| 3 | Break-glass used | Quarterly break-glass test (runbooks/break-glass.md) | sr-lz-breakglass-alerts email |
| 4 | VPN tunnel down | Disable one tunnel on the customer gateway during a maintenance window | Tunnel alarm topic |
| 5 | Budget / anomaly | Temporarily lower a Sandbox budget to 1 USD | Cost alert email |

| Date | # | Triggered by | Received (min) | Notes |
|------|---|--------------|----------------|-------|
| | | | | |
