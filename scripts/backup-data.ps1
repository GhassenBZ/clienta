$ErrorActionPreference = "Stop"

param(
    [string]$UploadBucketName,
    [string]$OutputDirectory = ".\backups"
)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDirectory = Join-Path $OutputDirectory $timestamp
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

$snapshotIdentifier = "vikunja-manual-$timestamp"
aws rds create-db-snapshot `
    --db-instance-identifier vikunja-db `
    --db-snapshot-identifier $snapshotIdentifier `
    --region us-east-1
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create RDS snapshot $snapshotIdentifier."
}
Set-Content -LiteralPath (Join-Path $backupDirectory "rds-snapshot.txt") -Value $snapshotIdentifier

if ([string]::IsNullOrWhiteSpace($UploadBucketName)) {
    $uploadBucketName = aws cloudformation describe-stacks `
        --stack-name vikunja-artifacts-stack `
        --query "Stacks[0].Outputs[?OutputKey=='UploadBucketName'].OutputValue" `
        --output text `
        --region us-east-1
}

if ([string]::IsNullOrWhiteSpace($UploadBucketName)) {
    throw "Upload bucket name was not provided or found."
}

$uploadDirectory = Join-Path $backupDirectory "s3-uploads"
New-Item -ItemType Directory -Path $uploadDirectory -Force | Out-Null
aws s3 cp "s3://$UploadBucketName/vikunja-files/" $uploadDirectory --recursive --region us-east-1
if ($LASTEXITCODE -ne 0) {
    throw "Failed to back up upload bucket."
}

Write-Output "RDS snapshot: $snapshotIdentifier"
Write-Output "S3 upload backup: $uploadDirectory"
