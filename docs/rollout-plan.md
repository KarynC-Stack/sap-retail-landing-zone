# Rollout plan: console-built org to IaC

Each phase is a separate change window. A phase only starts when the previous phase's exit check passes.
Commands are run from the repo root, signed in with `aws sso login --profile sr-lz-mgmt`.
Every `deploy.ps1` call without `-Execute` only creates and prints a change set.

| Phase | What happens | Risk to live workloads | Exit check |
|-------|--------------|------------------------|------------|
| 0 | Back up and inventory (done 2026-11-18) | None (read-only) | `.work/export-*` and `.work/inventory` exist |
| 1 | Bootstrap the pipeline | None | `sr-lz-bootstrap` CREATE_COMPLETE |
| 2 | Import Control Tower, OUs and accounts (no changes) | None | Import change sets show only `Import` actions |
| 3 | Rename accounts and OUs; create the new OUs; register them with Control Tower | Low (names only) | verify Q1.3, Q1.4, Q1.5 |
| 4 | Identity Center: new groups, permission sets and assignments, plus break-glass | Low (additive) | You can sign in with SR-PowerUser / SR-ReadOnly in every account |
| 5 | Security services: delegated admins, GuardDuty org-wide, Security Hub central config, Access Analyzer | Low | verify Q2.2, Q3.5, Q4.3, Q4.4 |
| 6 | Log Archive Object Lock bucket, then switch Control Tower to it | Low | verify Q6.2, Q6.3 |
| 7 | SCPs and tag policy. Test in Sandbox first, then attach everywhere. Delete the console SCPs | **Medium** (guardrails) | verify Q2.1, Q7.1. No errors from Data Platform jobs for 24h |
| 8 | StackSets: audit role, APN enforcer, scheduler; network hub | Low | verify Q2.3, Q4.6, Q5.1 |
| 9 | Cost governance | None | verify Q7.2, Q7.3 |
| 10 | Move Kenya Non-Production, then Data Platform, into their OUs | **Medium** (new SCPs apply) | Data Platform smoke test passes |
| 11 | Invite Kenya Production from the Kitstek org | **High** (separate window) | runbooks/kenya-production-invite.md |
| 12 | Cutover: remove interim admin access, delete console-built stacks and analyzer, tidy the landing zone | Low | verify 100% PASS; dry-run the audit agent |

## Phase 1: bootstrap
```powershell
scripts\deploy.ps1 -Stack sr-lz-bootstrap -Profile sr-lz-mgmt            # review
scripts\deploy.ps1 -Stack sr-lz-bootstrap -Profile sr-lz-mgmt -Execute
```
Then create the GitHub repo `<GITHUB_OWNER>/sap-retail-lz-iac` with these environments:
- `management`: required reviewer
- `management-plan`
- `verify`

Protect `main` so that changes need a PR, one approval and passing checks.

## Phase 2: imports (no-op adoption)
```powershell
scripts\deploy.ps1 -Stack sr-lz-controltower -Import -Profile sr-lz-mgmt      # expect: Import LandingZone only
scripts\deploy.ps1 -Stack sr-lz-controltower -Import -Profile sr-lz-mgmt -Execute
scripts\deploy.ps1 -Stack sr-lz-organization -Import -Profile sr-lz-mgmt      # 4 OUs + 4 accounts, Import only
scripts\deploy.ps1 -Stack sr-lz-organization -Import -Profile sr-lz-mgmt -Execute
```
`sr-lz-ct-governance` is imported in phase 3, because it needs the new OU exports first.

## Phase 3: names and OU structure
```powershell
scripts\enable-org-features.ps1 -Apply      # step 5 renames the management account ("SAP B1" to "Management")
scripts\deploy.ps1 -Stack sr-lz-organization -Profile sr-lz-mgmt -Execute   # renames + 6 new OUs; NO account moves (MoveWorkloadAccounts=false)
scripts\deploy.ps1 -Stack sr-lz-ct-governance -Import -Profile sr-lz-mgmt -Execute
scripts\deploy.ps1 -Stack sr-lz-ct-governance -Profile sr-lz-mgmt -Execute     # registers the 6 new OUs + detective controls (~1-2 h)
```
Only after every new OU shows SUCCEEDED (verify Q1.4), set `MoveWorkloadAccounts` to `true` in
`config/parameters/organization.json` and deploy `sr-lz-organization` again. That moves Kenya Non-Production
into Workloads/Kenya/Non-Production, which is already registered. Then enrol it:
```powershell
aws controltower reset-enabled-baseline --enabled-baseline-identifier <Kenya/Non-Production baseline ARN> --profile sr-lz-mgmt
```

## Phase 4: identity
1. Deploy `sr-lz-identity`, then `sr-lz-break-glass` in eu-west-1 and us-east-1.
2. Every engineer signs in with the new permission sets and confirms access.
3. Hand over the break-glass credentials as described in runbooks/break-glass.md.

Keep the Control Tower `AWSAdministratorAccess` assignment for the platform operator until phase 12, so there's an interim way back in.

## Phase 5: security services
`scripts\enable-org-features.ps1` is a dry-run checklist. It prints the commands and never applies anything, so there is no `-Apply` switch. The organization-level steps that have no CloudFormation resource type are run by hand from the management account, in this order, and the output is captured as evidence:

1. Enable trusted access: `aws organizations enable-aws-service-access --service-principal <access-analyzer|securityhub|guardduty|ram>.amazonaws.com`.
2. Register delegated administrators. Access Analyzer and Config use `aws organizations register-delegated-administrator`. GuardDuty uses `aws guardduty enable-organization-admin-account`. Security Hub uses `aws securityhub enable-organization-admin-account`. Security Hub's administrator is not set by the Organizations call, which is an easy mistake to make.
3. From the Security Tooling account, set GuardDuty auto-enable with `aws guardduty update-organization-configuration --auto-enable-organization-members ALL`. Do this before SCPs are attached, because `security-services-protection` denies that call.
4. EBS malware protection is left off. AWS requires the management account to enable it for the organization first, and the call is rejected otherwise.

The Security Tooling stack is delivered by `sr-lz-stacksets`. Each StackSet has its own `Enable...StackSet` flag in `config/parameters/stacksets.json`. Turn them on one at a time through a reviewed change set, because every member template uses `DeletionPolicy: Retain` and a failed deploy leaves fixed-name resources behind.

## Phase 6: logging
Control Tower creates and manages its own log buckets (design decision 13). They have versioning but no Object Lock, and Object Lock cannot be added to an existing bucket, so write-once retention is delivered by replication (design decision 14).
1. `sr-lz-log-archive` (StackSet) creates the Object Lock archive bucket, its access-log bucket and the replication role.
2. The same stack applies the replication configuration to the Control Tower log bucket through a custom resource, so it stays in code and is re-applied on every update.
3. Replication covers new objects only. Existing Control Tower logs would need S3 Batch Replication, which is not run without approval.
4. Deploy this before the SCPs. `log-archive-protection` denies `s3:PutBucketObjectLockConfiguration`, which creating the archive bucket is expected to need.
4. Keep the old `aws-controltower-*` log buckets. They hold the history from before the switch. Don't delete them.

## Phase 7: guardrails
1. Deploy `sr-lz-scps` with only the Sandbox SCP targets enabled, and run a smoke test (launch, tag, delete).
2. Deploy the full `sr-lz-scps`.
3. Deploy `sr-lz-tag-policy`.
4. Run `scripts\teardown-console-resources.ps1 -Phase scps -Apply` and `-Phase tagpolicy -Apply`.

Rollback: revert the PR and redeploy. SCP changes take effect within minutes.

## Phase 10: Data Platform
Before the move:
- Confirm the Data Platform pipelines tag the resources they create with `aws-apn-id`. They already deploy with stack-level tags.
- Confirm they only use eu-west-1.

Then:
1. Add the `DataPlatformAccount` resource to `organization.yaml` with `ParentIds: [!Ref KenyaProductionOU]`.
2. Add an import entry for `<EXCLUDED_ACCOUNT_ID>` and run an IMPORT followed by an UPDATE.
3. Reset the Kenya/Production enabled baseline so the account is enrolled.

Smoke test: the Databricks job runs, the peering to the SAP account is still active, and no AccessDenied errors appear in CloudTrail for 24h.

## Phase 12: cutover
1. Remove the interim `AWSAdministratorAccess` assignments in Identity Center.
2. Delete the IAM user `the platform operator` in the management account, once break-glass has been tested.
3. `scripts\teardown-console-resources.ps1 -Phase stacks -Apply`
4. Remove `ca-central-1` from the governed Regions, once the inventory shows nothing runs there.
5. Run `verify\verify.ps1` and require 100% PASS.
6. Run the Delivery Kit Path A prompt against the repo as a dry run of the audit.
