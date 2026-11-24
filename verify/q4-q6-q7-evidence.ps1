# SAP_Retail read-only evidence capture for Q4 (security services), Q6 (logging) and Q7 (cost and tagging).
# It only calls describe/list/get APIs. It never changes AWS resources.
# Each check writes its raw output to a file and the index records whether the command itself succeeded.
# "CAPTURED" means output exists to inspect. It does NOT mean the control is operating effectively.
param(
  [Parameter(Mandatory)][string]$Profile,
  [string]$Region = 'eu-west-1',
  [string]$OutRoot = ''
)
if (-not $OutRoot) { $OutRoot = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\audit\evidence' }
$ErrorActionPreference = 'Continue'
$mgmt = '<MANAGEMENT_ACCOUNT_ID>'; $logArchive = '<LOG_ARCHIVE_ACCOUNT_ID>'; $secTooling = '<SECURITY_TOOLING_ACCOUNT_ID>'; $rootId = '<ROOT_ID>'
$sourceBucket = 'aws-controltower-cloudtrail-logs-<LOG_ARCHIVE_ACCOUNT_ID>-<CT_BUCKET_SUFFIX>'
$archiveBucket = 'sr-lz-log-archive-<LOG_ARCHIVE_ACCOUNT_ID>-eu-west-1'

$caller = aws sts get-caller-identity --profile $Profile --query Account --output text 2>$null
if ($caller -ne $mgmt) { throw "Run with a verified management-account profile ($mgmt). Got '$caller'." }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$dir = Join-Path $OutRoot $stamp
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$index = New-Object System.Collections.Generic.List[object]

function Save-Check($id, $control, $file, [scriptblock]$cmd) {
  $path = Join-Path $dir $file
  $out = & $cmd 2>&1 | Out-String
  $ok = ($LASTEXITCODE -eq 0)
  $out | Set-Content -Path $path -Encoding utf8
  $index.Add([pscustomobject]@{ Id = $id; Control = $control; CommandSucceeded = $ok; File = $file; CapturedAt = (Get-Date -Format s) })
}

# Run a block inside a member account with short-lived credentials, then restore the caller's environment.
function In-Account($acct, [scriptblock]$block) {
  $c = aws sts assume-role --role-arn "arn:aws:iam::${acct}:role/OrganizationAccountAccessRole" --role-session-name sr-evidence --profile $Profile --output json | ConvertFrom-Json
  $saved = @{ K = $env:AWS_ACCESS_KEY_ID; S = $env:AWS_SECRET_ACCESS_KEY; T = $env:AWS_SESSION_TOKEN; R = $env:AWS_DEFAULT_REGION }
  try {
    $env:AWS_ACCESS_KEY_ID = $c.Credentials.AccessKeyId; $env:AWS_SECRET_ACCESS_KEY = $c.Credentials.SecretAccessKey
    $env:AWS_SESSION_TOKEN = $c.Credentials.SessionToken; $env:AWS_DEFAULT_REGION = $Region
    & $block
  } finally {
    $env:AWS_ACCESS_KEY_ID = $saved.K; $env:AWS_SECRET_ACCESS_KEY = $saved.S; $env:AWS_SESSION_TOKEN = $saved.T; $env:AWS_DEFAULT_REGION = $saved.R
  }
}

# ---------------- Q1/Q2/Q3: organization, accounts, identity ----------------
Save-Check 'Q1.1' 'Organization' 'q1-organization.json' { aws organizations describe-organization --profile $Profile --region $Region --output json }
Save-Check 'Q2.1' 'Accounts, state and OU paths' 'q2-accounts.json' { aws organizations list-accounts --profile $Profile --region $Region --output json }
Save-Check 'Q2.2' 'OUs under root' 'q2-ous-root.json' { aws organizations list-organizational-units-for-parent --parent-id $rootId --profile $Profile --region $Region --output json }
Save-Check 'Q3.1' 'Identity Center instance' 'q3-identity-center.json' { aws sso-admin list-instances --profile $Profile --region $Region --output json }
Save-Check 'Q3.2' 'Identity Center groups' 'q3-identity-groups.json' { $s = aws sso-admin list-instances --profile $Profile --region $Region --query 'Instances[0].IdentityStoreId' --output text; aws identitystore list-groups --identity-store-id $s --profile $Profile --region $Region --output json }
Save-Check 'Q3.3' 'Permission sets (name and session duration)' 'q3-permission-sets.json' { $i = aws sso-admin list-instances --profile $Profile --region $Region --query 'Instances[0].InstanceArn' --output text; $arns = (aws sso-admin list-permission-sets --instance-arn $i --profile $Profile --region $Region --output json | ConvertFrom-Json).PermissionSets; $arns | ForEach-Object { (aws sso-admin describe-permission-set --instance-arn $i --permission-set-arn $_ --profile $Profile --region $Region --query 'PermissionSet.[Name,SessionDuration]' --output json | ConvertFrom-Json) -join ' ' }; "count: $($arns.Count)" }
Save-Check 'Q3.4' 'Account assignments for SR-Administrators' 'q3-admin-assignments.json' { $i = aws sso-admin list-instances --profile $Profile --region $Region --query 'Instances[0].InstanceArn' --output text; $s = aws sso-admin list-instances --profile $Profile --region $Region --query 'Instances[0].IdentityStoreId' --output text; $g = aws identitystore list-groups --identity-store-id $s --profile $Profile --region $Region --query "Groups[?DisplayName=='SR-Administrators'].GroupId | [0]" --output text; aws sso-admin list-account-assignments-for-principal --instance-arn $i --principal-id $g --principal-type GROUP --profile $Profile --region $Region --output json }

# ---------------- Q4: security services ----------------
Save-Check 'Q4.1' 'Security Hub administrator' 'q4-securityhub-admin.json' { aws securityhub list-organization-admin-accounts --profile $Profile --region $Region --output json }
Save-Check 'Q4.2' 'GuardDuty administrator' 'q4-guardduty-admin.json' { aws guardduty list-organization-admin-accounts --profile $Profile --region $Region --output json }
Save-Check 'Q4.3' 'Delegated administrator services' 'q4-delegated-services.json' { aws organizations list-delegated-services-for-account --account-id $secTooling --profile $Profile --region $Region --output json }
Save-Check 'Q4.4' 'Security Hub central configuration' 'q4-securityhub-org-config.json' { In-Account $secTooling { aws securityhub describe-organization-configuration --output json } }
Save-Check 'Q4.5' 'Security Hub configuration policies' 'q4-securityhub-policies.json' { In-Account $secTooling { aws securityhub list-configuration-policies --output json } }
Save-Check 'Q4.6' 'Access Analyzer (organization)' 'q4-analyzer-org.json' { In-Account $secTooling { aws accessanalyzer list-analyzers --type ORGANIZATION --output json } }
Save-Check 'Q4.7' 'Access Analyzer (unused access)' 'q4-analyzer-unused.json' { In-Account $secTooling { aws accessanalyzer list-analyzers --type ORGANIZATION_UNUSED_ACCESS --output json } }
Save-Check 'Q4.8' 'GuardDuty organization configuration' 'q4-guardduty-org-config.json' { In-Account $secTooling { $d = aws guardduty list-detectors --query 'DetectorIds[0]' --output text; aws guardduty describe-organization-configuration --detector-id $d --output json } }
Save-Check 'Q4.9' 'GuardDuty members' 'q4-guardduty-members.json' { In-Account $secTooling { $d = aws guardduty list-detectors --query 'DetectorIds[0]' --output text; aws guardduty list-members --detector-id $d --only-associated false --output json } }
Save-Check 'Q4.10' 'Findings topic subscription state' 'q4-findings-subscriptions.json' { In-Account $secTooling { $t = aws sns list-topics --query "Topics[?contains(TopicArn,'sr-lz-security-findings')].TopicArn | [0]" --output text; aws sns list-subscriptions-by-topic --topic-arn $t --output json } }
Save-Check 'Q4.11' 'Findings topic policy' 'q4-findings-topic-policy.json' { In-Account $secTooling { $t = aws sns list-topics --query "Topics[?contains(TopicArn,'sr-lz-security-findings')].TopicArn | [0]" --output text; aws sns get-topic-attributes --topic-arn $t --query 'Attributes.Policy' --output text } }
Save-Check 'Q4.12' 'Findings routing rule' 'q4-findings-rule.json' { In-Account $secTooling { aws events describe-rule --name sr-lz-securityhub-critical-high --output json } }
Save-Check 'Q4.14' 'Security Hub policy associations (summary)' 'q4-securityhub-associations.json' { In-Account $secTooling { aws securityhub list-configuration-policy-associations --output json } }
Save-Check 'Q4.15' 'Security Hub standards enabled in Log Archive (member sample)' 'q4-securityhub-standards-logarchive.json' { In-Account $logArchive { aws securityhub get-enabled-standards --output json } }
Save-Check 'Q4.16' 'Security Hub standards enabled in Networking' 'q4-securityhub-standards-networking.json' { In-Account '<NETWORK_ACCOUNT_ID>' { aws securityhub get-enabled-standards --output json } }
Save-Check 'Q4.17' 'Security Hub standards enabled in Kenya Non-Production' 'q4-securityhub-standards-kenya-nonprod.json' { In-Account '<KENYA_NONPROD_ACCOUNT_ID>' { aws securityhub get-enabled-standards --output json } }
Save-Check 'Q4.18' 'Management account Security Hub subscription (expected: not subscribed, decision 23)' 'q4-securityhub-mgmt.json' { aws securityhub describe-hub --profile $Profile --region $Region --output json }
Save-Check 'Q4.13' 'Cross-account audit role StackSet instances' 'q4-audit-role-instances.json' { aws cloudformation list-stack-instances --stack-set-name sr-lz-security-audit-role --call-as SELF --profile $Profile --region $Region --output json }

# ---------------- Q6: logging and retention ----------------
Save-Check 'Q6.1' 'Archive bucket Object Lock' 'q6-archive-object-lock.json' { In-Account $logArchive { aws s3api get-object-lock-configuration --bucket $archiveBucket --output json } }
Save-Check 'Q6.2' 'Archive bucket versioning' 'q6-archive-versioning.json' { In-Account $logArchive { aws s3api get-bucket-versioning --bucket $archiveBucket --output json } }
Save-Check 'Q6.3' 'Source bucket replication configuration' 'q6-source-replication.json' { In-Account $logArchive { aws s3api get-bucket-replication --bucket $sourceBucket --output json } }
Save-Check 'Q6.4' 'Objects present in the archive (first 5)' 'q6-archive-objects.json' { In-Account $logArchive { aws s3api list-objects-v2 --bucket $archiveBucket --max-items 5 --output json } }
Save-Check 'Q6.5' 'Organization trail' 'q6-cloudtrail.json' { aws cloudtrail describe-trails --profile $Profile --region $Region --output json }
Save-Check 'Q6.6' 'Control Tower landing zone' 'q6-controltower.json' { $lz = aws controltower list-landing-zones --profile $Profile --region $Region --query 'landingZones[0].arn' --output text; aws controltower get-landing-zone --landing-zone-identifier $lz --profile $Profile --region $Region --output json }

# ---------------- Q7: cost and tagging ----------------
Save-Check 'Q7.1' 'Tag policy type enabled on root' 'q7-root-policy-types.json' { aws organizations list-roots --profile $Profile --region $Region --query 'Roots[0].PolicyTypes' --output json }
Save-Check 'Q7.2' 'Tag policies' 'q7-tag-policies.json' { aws organizations list-policies --filter TAG_POLICY --profile $Profile --region $Region --output json }
Save-Check 'Q7.8' 'Tag policy content' 'q7-tag-policy-content.json' { $id = aws organizations list-policies --filter TAG_POLICY --profile $Profile --region $Region --query 'Policies[0].Id' --output text; aws organizations describe-policy --policy-id $id --profile $Profile --region $Region --query 'Policy.Content' --output text }
Save-Check 'Q7.9' 'Tag policy attachments' 'q7-tag-policy-targets.json' { $id = aws organizations list-policies --filter TAG_POLICY --profile $Profile --region $Region --query 'Policies[0].Id' --output text; aws organizations list-targets-for-policy --policy-id $id --profile $Profile --region $Region --output json }
Save-Check 'Q7.3' 'Budgets' 'q7-budgets.json' { aws budgets describe-budgets --account-id $mgmt --profile $Profile --region us-east-1 --output json }
Save-Check 'Q7.4' 'Anomaly monitors' 'q7-anomaly-monitors.json' { aws ce get-anomaly-monitors --profile $Profile --region us-east-1 --output json }
Save-Check 'Q7.5' 'Anomaly subscriptions' 'q7-anomaly-subscriptions.json' { aws ce get-anomaly-subscriptions --profile $Profile --region us-east-1 --output json }
Save-Check 'Q7.6' 'Active cost allocation tags' 'q7-cost-allocation-tags.json' { aws ce list-cost-allocation-tags --status Active --profile $Profile --region us-east-1 --output json }
Save-Check 'Q7.7' 'Instance scheduler StackSet instances' 'q7-scheduler-instances.json' { aws cloudformation list-stack-instances --stack-set-name sr-lz-instance-scheduler --call-as SELF --profile $Profile --region $Region --output json }

# ---------------- Guardrails ----------------
Save-Check 'G.1' 'SCPs attached to root' 'g-scps-root.json' { aws organizations list-policies-for-target --target-id $rootId --filter SERVICE_CONTROL_POLICY --profile $Profile --region $Region --output json }

$index | ConvertTo-Json | Set-Content (Join-Path $dir 'index.json') -Encoding utf8
$md = @("# Evidence capture $stamp", '', 'CommandSucceeded only means the API call returned. Read the raw file to judge the control. Operational evidence (alert tests, retention sign-off, SIEM, training) is not produced by this script.', '', '| Id | Control | CommandSucceeded | File |', '|---|---|---|---|')
$md += $index | ForEach-Object { "| $($_.Id) | $($_.Control) | $($_.CommandSucceeded) | $($_.File) |" }
$md | Set-Content (Join-Path $dir 'index.md') -Encoding utf8
Write-Host "evidence: wrote $($index.Count) checks to $dir (read-only)"
