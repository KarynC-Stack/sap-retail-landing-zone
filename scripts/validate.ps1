$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$templatePaths = Get-ChildItem -Path (Join-Path $repositoryRoot 'templates') -Filter '*.yaml' -File

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

Write-Host "Validated $($templatePaths.Count) generic CloudFormation template(s) and placeholder configuration."
