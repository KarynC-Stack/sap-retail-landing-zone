# Identity Center settings that have no API (Q3)

These are set in the IAM Identity Center console (Settings, then Authentication) because no CloudFormation or public API exists for them. Record evidence here after each review.

| Setting | Required value | Questionnaire |
|---------|----------------|---------------|
| AWS access portal session duration | 8 hours | Q3 "portal sessions at 8 hours" |
| Prompt users for MFA | Every time they sign in (context-aware off) | Q3 "MFA mandatory for all users" |
| Users can authenticate with | Security keys and built-in authenticators + authenticator apps | Q3 |
| If a user does not yet have a registered MFA device | Require them to register an MFA device at sign in | Q3 |

Role session length (1 hour) is enforced in code: `SessionDuration: PT1H` on every permission set (verify Q3.1, guard rule `permission_sets_one_hour`).

| Date reviewed | By | Screenshot / ticket |
|---------------|----|---------------------|
| | | |
