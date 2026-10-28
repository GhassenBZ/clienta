$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildDir = Join-Path $repoRoot "build"
$stageDir = Join-Path $buildDir "clienta-app-stage"
$archivePath = Join-Path $buildDir "clienta-app.tar.gz"
$nodeArchive = Join-Path $buildDir "node-v24.22.2-linux-x64.tar.gz"
$nodeExtractDir = Join-Path $buildDir "clienta-node-runtime"
$nodeFolder = "node-v24.22.2-linux-x64"
$nodeUrl = "https://nodejs.org/dist/v24.22.2/${nodeFolder}.tar.gz"
$nodeSha256 = "361718c444e49af2ca5a110c83ba6a8901143f23ab285ebbef0341f391f482a9"

function Copy-DeploymentFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        if ($item.Name -eq "node_modules" -or $item.Name -like ".env*") {
            continue
        }

        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
if (Test-Path -LiteralPath $stageDir) {
    Remove-Item -LiteralPath $stageDir -Recurse -Force
}
if (Test-Path -LiteralPath $nodeArchive) {
    Remove-Item -LiteralPath $nodeArchive -Force
}
if (Test-Path -LiteralPath $nodeExtractDir) {
    Remove-Item -LiteralPath $nodeExtractDir -Recurse -Force
}

New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
Copy-DeploymentFiles (Join-Path $repoRoot "app\backend") (Join-Path $stageDir "app\backend")
Copy-DeploymentFiles (Join-Path $repoRoot "app\frontend") (Join-Path $stageDir "app\frontend")
Copy-DeploymentFiles (Join-Path $repoRoot "app\database") (Join-Path $stageDir "app\database")

Push-Location (Join-Path $stageDir "app\backend")
try {
    & npm.cmd ci --omit=dev --legacy-peer-deps
    if ($LASTEXITCODE -ne 0) {
        throw "npm ci failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeArchive -UseBasicParsing
$actualSha256 = (Get-FileHash -LiteralPath $nodeArchive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $nodeSha256) {
    throw "Node.js archive checksum mismatch: expected $nodeSha256, received $actualSha256."
}

New-Item -ItemType Directory -Path $nodeExtractDir -Force | Out-Null
& tar.exe -xzf $nodeArchive -C $nodeExtractDir "$nodeFolder/bin/node" "$nodeFolder/LICENSE"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to extract the verified Node.js runtime archive."
}

$runtimeDir = Join-Path $stageDir "runtime"
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $nodeExtractDir "$nodeFolder/bin/node") -Destination (Join-Path $runtimeDir "node")
Copy-Item -LiteralPath (Join-Path $nodeExtractDir "$nodeFolder/LICENSE") -Destination (Join-Path $runtimeDir "LICENSE.node")

$normalizedTimestamp = [datetime]::Parse("2020-01-01T00:00:00Z").ToUniversalTime()
$stagedEntries = @(Get-ChildItem -LiteralPath $stageDir -Recurse -Force) + @((Get-Item -LiteralPath $stageDir))
foreach ($entry in $stagedEntries) {
    $entry.LastWriteTimeUtc = $normalizedTimestamp
}

& tar.exe -czf $archivePath -C $stageDir .
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create the application bundle."
}

$archiveStream = [System.IO.File]::OpenWrite($archivePath)
try {
    $archiveStream.Position = 4
    $zeroTimestamp = [byte[]](0, 0, 0, 0)
    $archiveStream.Write($zeroTimestamp, 0, $zeroTimestamp.Length)
}
finally {
    $archiveStream.Dispose()
}

Remove-Item -LiteralPath $nodeArchive -Force
Remove-Item -LiteralPath $nodeExtractDir -Recurse -Force
Remove-Item -LiteralPath $stageDir -Recurse -Force

$bundleHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Output "Created $archivePath"
Write-Output "SHA-256: $bundleHash"
