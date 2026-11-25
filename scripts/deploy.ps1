# Safe change-set helper. It creates no organization memberships and executes nothing unless -Execute is explicitly supplied.
param([string[]]$Stack,[switch]$All,[switch]$Execute,[string]$Profile='',[string]$GitSha='local')
$ErrorActionPreference='Stop'; $repo=Resolve-Path (Join-Path $PSScriptRoot '..'); $cfg=Get-Content "$repo\config\stacks.json" -Raw|ConvertFrom-Json
$common=@('--region',$cfg.region);if($Profile){$common+=@('--profile',$Profile)}
$caller=aws sts get-caller-identity --query Account --output text @common
if($LASTEXITCODE -ne 0 -or $caller -ne '<MANAGEMENT_ACCOUNT_ID>'){throw 'Refusing operation: caller must be fresh management account <MANAGEMENT_ACCOUNT_ID>.'}
if($Execute){$active=aws controltower list-landing-zone-operations --query "landingZoneOperations[?status=='IN_PROGRESS'].operationIdentifier" --output text @common 2>$null;if($active){throw "Refusing operation: Control Tower operation remains IN_PROGRESS: $active"}}
$targets=if($All){$cfg.stacks|Where-Object {$_.pipeline -eq $true}}else{$cfg.stacks|Where-Object {$Stack -contains $_.name}}
if(-not $targets){throw 'No eligible stacks selected. Bootstrap and adoption stacks are manual-only; use an explicit -Stack after approvals.'}
# A stack that is already mid-operation is a transient state of the account, not a defect in this pipeline, so it is
# recorded and skipped rather than failing the whole plan run. If every stack was skipped the run still fails, because
# then it proved nothing. Any other CreateChangeSet error is a real failure and still stops the run.
$skipped=@()
foreach($s in $targets){$params=@();if($s.parameters){$params=Get-Content (Join-Path $repo $s.parameters)-Raw|ConvertFrom-Json;foreach($p in $params){if("$($p.ParameterValue)" -match '^(OPEN|SET_|DISCOVER_)'){throw "$($s.name): unresolved parameter $($p.ParameterKey)"}}}
  $cs="$($s.name)-$GitSha-$(Get-Date -Format yyyyMMddHHmmss)";$cli=@('cloudformation','create-change-set','--stack-name',$s.name,'--change-set-name',$cs,'--change-set-type','UPDATE','--template-body',"file://$(Join-Path $repo $s.template)",'--region',$cfg.region)
  if($params){$tmp=New-TemporaryFile;$json=$params|ConvertTo-Json -Depth 6;if($json -notmatch '^\s*\[' ){$json="[$json]"};$json|Set-Content $tmp -Encoding ascii;$cli+=@('--parameters',"file://$tmp")}
  $prev=$ErrorActionPreference;$ErrorActionPreference='Continue';$out=aws @cli @common 2>&1;$code=$LASTEXITCODE;$ErrorActionPreference=$prev
  $txt=($out|Out-String).TrimEnd();if($txt){Write-Host $txt}
  if($code){
    if($txt -match '_IN_PROGRESS state and can not be updated'){Write-Warning "$($s.name): stack is mid-operation, skipped this run";$skipped+=$s.name;continue}
    throw "Change-set creation failed for $($s.name)"
  }
  Write-Host "Created review-only change set $cs for $($s.name)"
  if($Execute){throw 'Execution is intentionally disabled in this fresh-organization package. Follow the approved runbook and execute the reviewed change set manually.'}
}
if($skipped.Count){Write-Host "Skipped because the stack was mid-operation, re-run when it settles: $($skipped -join ', ')"}
if($skipped.Count -eq @($targets).Count){throw 'Every selected stack was mid-operation, so nothing was planned. Re-run once the account settles.'}