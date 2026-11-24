# SAP_Retail Landing Zone Framework

A public, reusable CloudFormation framework for an AWS landing zone built on AWS Control Tower. It is the sanitised copy of a private deployment repository: the templates, scripts, design decisions and runbooks are the same, and every environment value has been replaced with a placeholder.

## Scope

This repository contains no account IDs, organization or OU IDs, email addresses, network ranges, identity data or operational evidence. Values appear as `<PLACEHOLDER>` tokens (for example `<MANAGEMENT_ACCOUNT_ID>`, `<SECURITY_OU_ID>`, `<PRIVATE_CIDR>`), and email addresses use `example.com`. Supply real values only in a private deployment repository.

Not included: deployment evidence, the audit status matrix, environment-specific migration runbooks, and scripts that inventory or change one specific organization.

## Contents

| Path | What it is |
|---|---|
| `templates/00-bootstrap` to `07-cost` | Organization, OUs, SCPs, tag policy, Control Tower, Identity Center permission sets, security StackSets (Security Hub central configuration, GuardDuty, Access Analyzer, findings alerts), write-once log archive, network hub and workload VPC, cost governance. |
| `bootstrap/github-oidc.yaml` | GitHub OIDC roles for a deployment pipeline. |
| `guard/rules` | CloudFormation Guard rules. |
| `config/` | Stack list and parameter files with placeholders, plus `sample-parameters.yaml`. |
| `scripts/` | Change-set helper, policy validation, organization feature checklist, offline validation. |
| `verify/` | Read-only evidence capture scripts. |
| `docs/` | Architecture, design decisions, controls mapping, tagging dictionary, rollout plan and generic runbooks. |
| `audit/traceability.md` | Generic control-to-evidence mapping. |

Read `docs/design-decisions.md` before deploying. It records where the build deliberately differs from defaults and why, including service limits found during deployment (for example Security Hub policy scope and GuardDuty member enrolment).

## Validate locally

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate.ps1
```

The validation is offline. It checks that every template has the required CloudFormation sections, that the sample configuration keeps its placeholders, and that no account ID, organization or OU ID, private network range, access key or real email domain has been committed. It does not call AWS.

## Use safely

1. Review the architecture and design decisions and decide the target operating model.
2. Copy the framework into a private deployment repository.
3. Replace every placeholder through approved private configuration and change control.
4. Review a change set before every deployment, then keep evidence according to your audit process.

## Security note

Do not commit credentials, account identifiers, organization identifiers, network ranges, endpoint addresses, resource identifiers or operational evidence to this public repository. `scripts/validate.ps1` runs in CI on every pull request and push to `main` and fails if it finds them.
