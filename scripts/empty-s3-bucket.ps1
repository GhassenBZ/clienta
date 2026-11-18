param(
    [Parameter(Mandatory = $true)]
    [string]$BucketName
)

$ErrorActionPreference = "Stop"

$deleteItems = @()
$nextKeyMarker = $null
$nextVersionMarker = $null

do {
    $arguments = @("s3api", "list-object-versions", "--bucket", $BucketName, "--output", "json")
    if ($nextKeyMarker) {
        $arguments += @("--key-marker", $nextKeyMarker)
    }
    if ($nextVersionMarker) {
        $arguments += @("--version-id-marker", $nextVersionMarker)
    }
    
    $versionsOutput = & aws @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list versions in bucket $BucketName."
    }

    $versions = $versionsOutput | ConvertFrom-Json
    foreach ($version in @($versions.Versions)) {
        $deleteItems += [ordered]@{ Key = $version.Key; VersionId = $version.VersionId }
    }
    foreach ($marker in @($versions.DeleteMarkers)) {
        $deleteItems += [ordered]@{ Key = $marker.Key; VersionId = $marker.VersionId }
    }

    $nextKeyMarker = $versions.NextKeyMarker
    $nextVersionMarker = $versions.NextVersionIdMarker
} while ($versions.IsTruncated)

for ($index = 0; $index -lt $deleteItems.Count; $index += 1000) {
    $batch = @($deleteItems[$index..[Math]::Min($index + 999, $deleteItems.Count - 1)])
    $deleteRequest = @{
        Objects = $batch
        Quiet   = $true
    } | ConvertTo-Json -Depth 5 -Compress

    aws s3api delete-objects --bucket $BucketName --delete $deleteRequest --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to empty bucket $BucketName."
    }
}

Write-Output "Emptied S3 bucket $BucketName."
