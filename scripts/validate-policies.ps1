# Optional non-mutating IAM Access Analyzer validation. Requires credentials for <MANAGEMENT_ACCOUNT_ID>.
param([string]$Profile='',[string]$Region='eu-west-1')
$repo=Resolve-Path (Join-Path $PSScriptRoot '..');$validator=Join-Path $repo '.venv\Scripts\cfn-policy-validator.exe';if(-not(Test-Path $validator)){$validator=(Get-Command cfn-policy-validator -ErrorAction Stop).Source}
if($Profile){$account=aws sts get-caller-identity --profile $Profile --query Account --output text 2>$null;if($account -ne '<MANAGEMENT_ACCOUNT_ID>'){throw 'Profile is unavailable or is not the target management account.'};$env:AWS_PROFILE=$Profile}
$runs=@(
 @{t='bootstrap/github-oidc.yaml';p=@('GitHubOwner=SET_APPROVED_OWNER','GitHubRepo=sap-retail-lz-iac','CreateOIDCProvider=true')},
 @{t='templates/03-identity/break-glass.yaml';p=@('CreateIdentity=false','SecurityAlertEmail=security@example.com')},
 @{t='templates/05-logging/log-archive.yaml';p=@('OrgId=o-aaaaaaaaaa')}
);$fail=0;foreach($r in $runs){&$validator validate --template-path (Join-Path $repo $r.t) --region $Region --parameters $r.p;if($LASTEXITCODE){$fail++}};exit $fail
