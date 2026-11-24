# SAP_Retail read-only evidence report. It never changes AWS resources.
param([switch]$ReadOnlyEvidence,[switch]$Ci,[string]$Profile='',[string]$Region='eu-west-1')
$repo=Resolve-Path (Join-Path $PSScriptRoot '..');$results=@();function Add($id,$status,$claim,$evidence){$script:results += [pscustomobject]@{ID=$id;Status=$status;Claim=$claim;Evidence=$evidence}}
if(-not $ReadOnlyEvidence){throw 'Use -ReadOnlyEvidence; no mutating verification mode exists.'}
$caller=if($Profile){aws sts get-caller-identity --profile $Profile --query Account --output text 2>$null}else{''}
if($caller -eq '<MANAGEMENT_ACCOUNT_ID>'){
 $org=aws organizations describe-organization --profile $Profile --region $Region --output json 2>$null|ConvertFrom-Json
 Add 'Q1' 'PASS' 'Fresh organization caller and organization evidence' "caller=$caller organization=$($org.Organization.Id)"
 Add 'Q2-Q10' 'UNVERIFIED' 'Live controls require an approved post-deployment evidence collection' 'Run the documented read-only AWS CLI checks after each approved phase.'
}else{Add 'Q1' 'UNVERIFIED' 'Fresh organization caller and organization evidence' 'No verified target-management profile supplied.'}
Add 'Uganda' 'DEFERRED' 'Uganda accounts, VPCs, VPN, monitoring and costs' 'No Uganda accounts are created or invited.'
Add 'Sandbox' 'DEFERRED' 'Sandbox account StackSet instances' 'Sandbox is an empty OU structural boundary.'
Add 'DataPlatform' 'DEFERRED' 'Data Platform migration and workload changes' 'Protected account; no invitation, enrollment, move, VPC change, or deployment is planned.'
$md=@('# SAP_Retail verification report',"Generated: $(Get-Date -Format s)",'','| ID | Status | Claim | Evidence |','|---|---|---|---|')+$results|ForEach-Object{"| $($_.ID) | $($_.Status) | $($_.Claim) | $($_.Evidence) |"};$md|Set-Content "$PSScriptRoot\report.md";$results|ConvertTo-Json|Set-Content "$PSScriptRoot\report.json";Write-Host "verify: report written (read-only)."
