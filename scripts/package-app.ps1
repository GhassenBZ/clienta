$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildDir = Join-Path $repoRoot "build"
$backendStageDir = Join-Path $buildDir "vikunja-backend-stage"
$frontendStageDir = Join-Path $buildDir "vikunja-frontend-stage"
$releaseDir = Join-Path $buildDir "vikunja-release"
$sourceDir = Join-Path $buildDir "vikunja-source"
$backendArchivePath = Join-Path $buildDir "vikunja-backend.tar.gz"
$frontendArchivePath = Join-Path $buildDir "vikunja-frontend.tar.gz"
$legacyArchivePath = Join-Path $buildDir "vikunja-app.tar.gz"
$releaseArchive = Join-Path $buildDir "vikunja-v2.8.0-linux-amd64-full.zip"
$sourceArchive = Join-Path $buildDir "vikunja-v2.8.0-source.zip"
$releaseUrl = "https://github.com/go-vikunja/vikunja/releases/download/v2.8.0/vikunja-v2.8.0-linux-amd64-full.zip"
$sourceUrl = "https://github.com/go-vikunja/vikunja/archive/refs/tags/v2.8.0.zip"
$releaseSha256 = "0b6ba2934bd432eefaa4209b0f96d20b7f7cd7f7be0269dd79071979c4363423"
$sourceSha256 = "59ac49e27ab346d07c5db324083d16392e8de338486dd32d26a008f40653e4f8"

function New-DeterministicTarGz {
    param(
        [string]$SourceDirectory,
        [string]$ArchivePath
    )

    $normalizedTimestamp = [datetime]::Parse("2020-01-01T00:00:00Z").ToUniversalTime()
    $stagedEntries = @(Get-ChildItem -LiteralPath $SourceDirectory -Recurse -Force) + @((Get-Item -LiteralPath $SourceDirectory))
    foreach ($entry in $stagedEntries) {
        $entry.LastWriteTimeUtc = $normalizedTimestamp
    }

    & "$env:SystemRoot\System32\tar.exe" -czf $ArchivePath -C $SourceDirectory .
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create bundle $ArchivePath."
    }

    $archiveStream = [System.IO.File]::OpenWrite($ArchivePath)
    try {
        $archiveStream.Position = 4
        $zeroTimestamp = [byte[]](0, 0, 0, 0)
        $archiveStream.Write($zeroTimestamp, 0, $zeroTimestamp.Length)
    }
    finally {
        $archiveStream.Dispose()
    }
}

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
foreach ($path in @(
        $backendArchivePath,
        $frontendArchivePath,
        $legacyArchivePath,
        $releaseArchive,
        $sourceArchive,
        $backendStageDir,
        $frontendStageDir,
        $releaseDir,
        $sourceDir
    )) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}

$nodeCommand = Get-Command node.cmd -ErrorAction SilentlyContinue
if (-not $nodeCommand) {
    $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
}
if (-not $nodeCommand) {
    throw "Node.js 24 or newer is required to build the Vikunja frontend."
}
$nodeVersion = (& $nodeCommand.Source --version).Trim().TrimStart("v")
if ($LASTEXITCODE -ne 0 -or [version]$nodeVersion -lt [version]"24.0") {
    throw "Vikunja v2.8.0 frontend requires Node.js 24 or newer; found $nodeVersion."
}

$pnpmCommand = Get-Command pnpm.cmd -ErrorAction SilentlyContinue
if (-not $pnpmCommand) {
    $pnpmCommand = Get-Command pnpm -ErrorAction SilentlyContinue
}
if (-not $pnpmCommand) {
    throw "pnpm 12.16.1 is required to build the Vikunja frontend."
}
$pnpmVersion = (& $pnpmCommand.Source --version).Trim()
if ($LASTEXITCODE -ne 0 -or $pnpmVersion -ne "12.16.1") {
    throw "The Vikunja frontend requires pnpm 12.16.1; found $pnpmVersion."
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $releaseUrl -OutFile $releaseArchive -UseBasicParsing
$actualReleaseSha256 = (Get-FileHash -LiteralPath $releaseArchive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualReleaseSha256 -ne $releaseSha256) {
    throw "Vikunja release checksum mismatch: expected $releaseSha256, received $actualReleaseSha256."
}

Invoke-WebRequest -Uri $sourceUrl -OutFile $sourceArchive -UseBasicParsing
$actualSourceSha256 = (Get-FileHash -LiteralPath $sourceArchive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSourceSha256 -ne $sourceSha256) {
    throw "Vikunja source checksum mismatch: expected $sourceSha256, received $actualSourceSha256."
}

New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
Expand-Archive -LiteralPath $releaseArchive -DestinationPath $releaseDir -Force
Expand-Archive -LiteralPath $sourceArchive -DestinationPath $sourceDir -Force

$binary = @(Get-ChildItem -LiteralPath $releaseDir -Recurse -File | Where-Object { $_.Name -eq "vikunja-v2.8.0-linux-amd64" })
$backendLicense = @(Get-ChildItem -LiteralPath $releaseDir -Recurse -File | Where-Object { $_.Name -eq "LICENSE" })
if ($binary.Count -ne 1 -or $backendLicense.Count -ne 1) {
    throw "The verified Vikunja server release did not contain exactly one binary and license."
}

$sourceRoot = Join-Path $sourceDir "vikunja-2.8.0"
$frontendSource = Join-Path $sourceRoot "frontend"
$frontendLicense = Join-Path $frontendSource "LICENSE"
if (-not (Test-Path -LiteralPath $frontendLicense)) {
    throw "The pinned Vikunja source archive does not contain the frontend license."
}

Push-Location $frontendSource
try {
    & $pnpmCommand.Source install --frozen-lockfile
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install the pinned Vikunja frontend dependencies."
    }
    # The upstream lockfile omits Rolldown's optional Windows binary during pnpm install.
    & $pnpmCommand.Source add --save-dev --save-exact @rolldown/binding-win32-x64-msvc@1.2.14
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install the pinned Windows frontend build binding."
    }
    & $pnpmCommand.Source run build
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build the Vikunja frontend."
    }
}
finally {
    Pop-Location
}

$frontendDist = Join-Path $frontendSource "dist"
if (-not (Test-Path -LiteralPath (Join-Path $frontendDist "index.html"))) {
    throw "The Vikunja frontend build did not produce dist/index.html."
}

$backendVikunjaDir = Join-Path $backendStageDir "vikunja"
$frontendWebDir = Join-Path $frontendStageDir "www"
New-Item -ItemType Directory -Path $backendVikunjaDir -Force | Out-Null
New-Item -ItemType Directory -Path $frontendWebDir -Force | Out-Null
Copy-Item -LiteralPath $binary[0].FullName -Destination (Join-Path $backendVikunjaDir "vikunja")
Copy-Item -LiteralPath (Join-Path $repoRoot "vikunja\seed-demo.py") -Destination $backendVikunjaDir
Copy-Item -LiteralPath (Join-Path $repoRoot "vikunja\demo-data.json") -Destination $backendVikunjaDir
Copy-Item -LiteralPath $backendLicense[0].FullName -Destination (Join-Path $backendVikunjaDir "LICENSE.vikunja")
Copy-Item -LiteralPath (Join-Path $frontendSource "LICENSE") -Destination (Join-Path $frontendStageDir "LICENSE.vikunja-frontend")
Copy-Item -LiteralPath (Join-Path $repoRoot "vikunja\serve_frontend.py") -Destination $frontendStageDir
Copy-Item -Path (Join-Path $frontendDist "*") -Destination $frontendWebDir -Recurse -Force

New-DeterministicTarGz -SourceDirectory $backendStageDir -ArchivePath $backendArchivePath
New-DeterministicTarGz -SourceDirectory $frontendStageDir -ArchivePath $frontendArchivePath

$backendBundleHash = (Get-FileHash -LiteralPath $backendArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
$frontendBundleHash = (Get-FileHash -LiteralPath $frontendArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Output "Created $backendArchivePath"
Write-Output "Backend bundle SHA-256: $backendBundleHash"
Write-Output "Created $frontendArchivePath"
Write-Output "Frontend bundle SHA-256: $frontendBundleHash"
Write-Output "Vikunja release SHA-256: $releaseSha256"
Write-Output "Vikunja source SHA-256: $sourceSha256"

foreach ($path in @($releaseArchive, $sourceArchive, $backendStageDir, $frontendStageDir, $releaseDir, $sourceDir)) {
    Remove-Item -LiteralPath $path -Recurse -Force
}
