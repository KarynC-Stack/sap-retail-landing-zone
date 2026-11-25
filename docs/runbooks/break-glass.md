# Runbook: break-glass access (Q3, Q4)

**When:** Identity Center is unavailable, or an incident needs administrator access that the standing permission sets don't grant.

## Commissioning status

The stack is deployed in **eu-west-1** (identity created) and **us-east-1** (alerting only). The identity is deliberately created without any usable credential, so three manual steps are required before break-glass works. Until all three are done the path is **not usable in an incident**.

| # | Step | Owner | Status |
|---|------|-------|--------|
| 1 | Confirm the two alert subscription emails, one per Region | the platform operator | **Outstanding.** Both subscriptions are `PendingConfirmation`, so the rule fires but nothing is delivered. |
| 2 | Register the FIDO2 security key as the user's MFA device | Custodian B | **Outstanding.** `list-mfa-devices` is empty. |
| 3 | Set the console password and seal it in the vault | Custodian A | **Outstanding.** `get-login-profile` returns `NoSuchEntity`. |
| 4 | Run the test below and record the result | Both custodians | Blocked on 1-3. |

Order matters. The role trust policy requires `aws:MultiFactorAuthPresent` and an MFA age under 900 seconds, so **step 2 must precede step 3** being useful: a password without a registered key cannot assume the role at all.

## Controls
| Control | How it is enforced |
|---------|--------------------|
| No long-lived credentials | The user has no access keys. `list-access-keys` is empty and must stay empty. |
| **Only** standing admin path | No `SR-*` permission set has any account assignment and the `SR-Administrators` group is deleted, so this role is the single standing administrator principal in the organization (design decision 31, superseding 17). Day-to-day access is Identity Center only. This IAM user is the deliberate exception to SSO-only, because Identity Center being unavailable is a condition it must cover. |
| Dual authorization | The `sr-breakglass` password and its hardware MFA key are held by two different named custodians. Neither can sign in alone. |
| Hardware MFA | The user's only MFA device is a FIDO2 security key. The role trust policy denies assumption without MFA present and under 15 minutes old. |
| 1-hour sessions | `BreakGlassAdministrator` has `MaxSessionDuration` 3600. |
| Scope | The role carries `AdministratorAccess` and is assumable only by `arn:aws:iam::<MANAGEMENT_ACCOUNT_ID>:user/breakglass/sr-breakglass`. |
| Immediate alert | EventBridge rule `sr-lz-breakglass-used` is `ENABLED` in eu-west-1 and us-east-1, targeting `sr-lz-breakglass-alerts`. The pattern catches role assumption, console sign-in as `sr-breakglass`, and any root console sign-in. The topic policy allows `events.amazonaws.com` to publish, scoped by `aws:SourceAccount`. |
| Audit trail | Organization CloudTrail replicates to the Log Archive Object Lock bucket, `GOVERNANCE` / 1460 days, with `s3:BypassGovernanceRetention` denied to every principal. |

## Custodians
| Role | Name | Holds |
|------|------|-------|
| Custodian A | <CUSTODIAN_A_NAME> (custodian-a@example.com) | Password (sealed, in the password vault) |
| Custodian B | <CUSTODIAN_B_NAME> (security-alerts@example.com) | FIDO2 key (safe) |

## Procedure
1. Open an incident ticket. Record the reason and the approver.
2. Custodian A and Custodian B both join the call. A enters the password and B touches the key.
3. Switch role to `BreakGlassAdministrator` in the management account. The alert email should arrive within minutes. If it doesn't, stop and investigate.
4. Do the minimum work needed. Record every action in the ticket.
5. Sign out. Rotate the password the same day, and record the CloudTrail event IDs in the ticket.

## Test (quarterly)
Run the procedure with a read-only action, such as `aws organizations describe-organization`, and confirm the alert arrives. Record the date here. The first run also serves as commissioning step 4 and is the evidence that the detection path works end to end.

| Date | Tested by | Alert received (min) |
|------|-----------|----------------------|
| | | |
