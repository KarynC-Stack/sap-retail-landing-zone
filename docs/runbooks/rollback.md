# Runbook: rollback (Q8)

Rollback means revert and redeploy. There are no manual reversal steps.

1. `git revert <merge-commit>` on a branch, then open a PR. CI shows the change set.
2. Merge after review. The deploy workflow applies the reverted templates.
3. Run `verify\verify.ps1` and confirm the previous PASS state is back.

## Safety nets
- Organizations accounts, OUs and the landing zone have `DeletionPolicy: Retain`. A bad change can't close an account or decommission Control Tower.
- `deploy.ps1` refuses change sets that remove or replace an account, OU or the landing zone unless `-AllowReplace` is given.
- Object Lock means log data can't be lost by rolling back.

## Exceptions
Control Tower landing zone updates can't be cancelled while they run. Wait for the operation to finish, then deploy the reverted manifest.

## Test record (Q8 "tested rollback capability")
| Date | Change reverted | Result | By |
|------|-----------------|--------|----|
| | e.g. SCP Sandbox test change | | |
