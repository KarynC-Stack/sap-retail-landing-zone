$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$templatePaths = Get-ChildItem -Path (Join-Path $repositoryRoot 'templates') -Filter '*.yaml' -File -Recurse

if ($templatePaths.Count -eq 0) {
    throw 'No CloudFormation templates were found.'
}

foreach ($templatePath in $templatePaths) {
    $content = Get-Content -Path $templatePath.FullName -Raw
    if ($content -notmatch 'AWSTemplateFormatVersion:' -or $content -notmatch 'Resources:') {
        throw "Template does not contain required CloudFormation sections: $($templatePath.Name)"
    }
}

$sampleConfiguration = Get-Content -Path (Join-Path $repositoryRoot 'config/sample-parameters.yaml') -Raw
if ($sampleConfiguration -notmatch '<[A-Z_]+>') {
    throw 'Sample configuration must retain placeholder values.'
}

# Public-repo leak scan: nothing environment-specific may be committed here.
$leakPatterns = @(
    '\b(?!000000000000\b)\d{12}\b',          # AWS account IDs
    '\bo-(?!a{10}\b)[a-z0-9]{10}\b',          # organization IDs
    '\bou-[a-z0-9]{4}-',                      # OU IDs
    'ssoins-[0-9a-f]',                        # Identity Center instance IDs
    '\b10\.\d+\.\d+\.\d+', '\b192\.168\.',    # private address ranges
    'AKIA[0-9A-Z]{16}',                       # access keys
    '(?i)\b(riffat|manji|ngugi|karen)\b',     # named people from the private deployment
    '@(?!example\.com)[A-Za-z0-9-]+\.(com|org|net|io)\b' # real email domains
)
$hits = @()
$files = Get-ChildItem -Path $repositoryRoot -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Name -ne 'validate.ps1' }
foreach ($file in $files) {
    $lineNumber = 0
    foreach ($line in (Get-Content -Path $file.FullName)) {
        $lineNumber++
        foreach ($pattern in $leakPatterns) {
            if ($line -match $pattern) { $hits += "$($file.FullName.Substring($repositoryRoot.Length + 1)):$lineNumber matches $pattern" }
        }
    }
}
if ($hits.Count -gt 0) {
    $hits | ForEach-Object { Write-Host $_ }
    throw "Leak scan failed with $($hits.Count) finding(s)."
}

Write-Host "Validated $($templatePaths.Count) CloudFormation template(s), placeholder configuration and leak scan."
