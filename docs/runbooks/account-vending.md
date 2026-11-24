# Runbook: vend a new account (Q1 account provisioning)

Accounts are created through a pull request. Nothing is clicked in the console.

1. Add the account to `config/org.yaml`: name, a new unique email, OU, country and environment.
2. Add an `AWS::Organizations::Account` resource to `templates/01-org/organization.yaml`:
   - `DeletionPolicy: Retain`
   - `ParentIds` set to the target OU, for example `UgandaProductionOU`
   - the standard tag set
3. Add a CIDR allocation to `config/network/cidr-plan.yaml`. CI rejects any overlap.
4. Add budget and Identity Center assignment entries in `cost-governance.yaml` and `permission-sets.yaml`.
5. Open the PR. CI runs lint, guard, policy validation and a change set preview. A second engineer approves.
6. Merge. The pipeline creates the account in the target OU.
7. Enroll the account in Control Tower: `aws controltower reset-enabled-baseline --enabled-baseline-identifier <OU baseline ARN>`.
8. The StackSets auto-deploy the account baseline:
   - KitstekSecurityAuditRole
   - APN tag enforcer
   - scheduler, for Non-Production accounts only

   Security Hub and GuardDuty also enable automatically.
9. Deploy `templates/06-network/workload-vpc.yaml` into the account with its parameters.
10. Run `verify\verify.ps1`.
