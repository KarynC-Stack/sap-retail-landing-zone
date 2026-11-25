# Dry-run-only checklist for organization features without CloudFormation resource types.
# It never applies changes. Execute each approved command manually during the applicable runbook phase.
param([string]$MgmtProfile='',[string]$SecurityToolingAccountId='<SECURITY_TOOLING_ACCOUNT_ID>',[string]$Region='eu-west-1')
$caller=aws sts get-caller-identity --profile $MgmtProfile --query Account --output text 2>$null
if($LASTEXITCODE -ne 0 -or $caller -ne '<MANAGEMENT_ACCOUNT_ID>'){throw 'Use a verified <MANAGEMENT_ACCOUNT_ID> management-account session.'}
@(
 "aws organizations register-delegated-administrator --account-id $SecurityToolingAccountId --service-principal access-analyzer.amazonaws.com",
 "aws organizations register-delegated-administrator --account-id $SecurityToolingAccountId --service-principal config.amazonaws.com",
 "aws guardduty enable-organization-admin-account --admin-account-id $SecurityToolingAccountId --region $Region",
 'GuardDuty: auto-enable did not enrol existing accounts. From Security Tooling run create-members for each member account. For the management account, first run create-detector --enable in that account, then create-members (design decision 24).',
 "aws securityhub enable-organization-admin-account --admin-account-id $SecurityToolingAccountId --region $Region",
 'Create the Access Analyzer service-linked role AWSServiceRoleForAccessAnalyzer in the management account before the Security Tooling StackSet, or the analyzers fail with AlreadyExists.',
 'Enable IAM Identity Center in the new organization, then record the discovered instance ARN and identity-store ID.',
 'Configure Security Hub delegated administration and central configuration after the Security Tooling account is adopted.',
 'Activate cost allocation tags (decision 29). The keys appear only after AWS sees them on billable resources, up to 24 hours: aws ce update-cost-allocation-tags-status --cost-allocation-tags-status TagKey=Client,Status=Active TagKey=ManagedBy,Status=Active TagKey=Country,Status=Active TagKey=Environment,Status=Active TagKey=aws-apn-id,Status=Active --region us-east-1'
) | ForEach-Object { Write-Host "MANUAL APPROVAL REQUIRED: $_" }
