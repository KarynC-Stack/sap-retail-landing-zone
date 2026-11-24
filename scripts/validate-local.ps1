# Local, non-mutating validation. AWS ValidateTemplate runs only when a supplied profile can read the target management account.
param([string]$Profile = '')
$ErrorActionPreference = 'Continue'
$repo = Resolve-Path (Join-Path $PSScriptRoot '..')
$report = Join-Path $repo '.work\validate-report.txt'; New-Item -ItemType Directory -Force -Path (Split-Path $report) | Out-Null
$templates = Get-ChildItem -Path "$repo\templates","$repo\bootstrap" -Recurse -Include *.yaml,*.yml
$fail=0; "validate-local $(Get-Date -Format s) templates=$($templates.Count)" | Set-Content $report
$cfnLint = Join-Path $repo '.venv\Scripts\cfn-lint.exe'; if (-not (Test-Path $cfnLint)) { $cfnLint=(Get-Command cfn-lint -ErrorAction SilentlyContinue).Source }
if ($cfnLint) { $out=& $cfnLint @($templates.FullName) 2>&1 | Out-String; "--- cfn-lint exit=$LASTEXITCODE`n$out" | Add-Content $report; if($LASTEXITCODE -ne 0){$fail++} } else { '--- cfn-lint unavailable' | Add-Content $report; $fail++ }
$policy=& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'repo-policy.ps1') 2>&1 | Out-String; "--- repo-policy exit=$LASTEXITCODE`n$policy" | Add-Content $report; if($LASTEXITCODE -ne 0){$fail++}
if ($Profile) { $id=aws sts get-caller-identity --profile $Profile --query Account --output text 2>$null; if($LASTEXITCODE -eq 0 -and $id -eq '<MANAGEMENT_ACCOUNT_ID>') { foreach($t in $templates){$r=aws cloudformation validate-template --template-body "file://$($t.FullName)" --profile $Profile --region eu-west-1 2>&1;if($LASTEXITCODE){$fail++;"INVALID $($t.Name): $r"|Add-Content $report}else{"VALID $($t.Name)"|Add-Content $report}} } else { '--- AWS ValidateTemplate skipped: profile unavailable or not target management account' | Add-Content $report } } else { '--- AWS ValidateTemplate skipped: no profile supplied' | Add-Content $report }
"--- RESULT: $(if($fail){"FAIL ($fail)"}else{'PASS'})" | Add-Content $report; Get-Content $report; exit $fail
