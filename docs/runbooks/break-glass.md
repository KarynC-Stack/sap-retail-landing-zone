# Runbook: break-glass access (Q3, Q4)

**When:** Identity Center is unavailable, or an incident needs administrator access that the standing permission sets don't grant.

## Controls
| Control | How it is enforced |
|---------|--------------------|
| No standing admin | `SR-Admin` permission set has no assignments (verify Q3.2) |
| Dual authorization | The `sr-breakglass` password and its hardware MFA key are held by two different named custodians. Neither can sign in alone. |
| Hardware MFA | The user's only MFA device is a FIDO2 security key. The IAM policy denies everything without MFA. |
| 1-hour sessions | `BreakGlassAdministrator` has MaxSessionDuration 3600 and requires MFA no older than 15 minutes |
| Immediate alert | EventBridge rule `sr-lz-breakglass-used` sends an email to the Kitstek security team on sign-in and on role assumption (eu-west-1 + us-east-1) |
| Audit trail | Organization CloudTrail goes to the Log Archive Object Lock bucket |

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
Run the procedure with a read-only action, such as `aws organizations describe-organization`, and confirm the alert arrives. Record the date here.

| Date | Tested by | Alert received (min) |
|------|-----------|----------------------|
| | | |
