param(
    [Parameter(Mandatory = $true)]
    [string]$InstanceId,
    [string]$Region = "us-east-1"
)

$ErrorActionPreference = "Stop"
$deadline = (Get-Date).AddMinutes(20)

$awsCommand = Get-Command aws -ErrorAction SilentlyContinue
if ($awsCommand) {
    $awsExecutable = $awsCommand.Source
}
else {
    $awsExecutable = Join-Path $env:ProgramFiles "Amazon\AWSCLIV2\aws.exe"
    if (-not (Test-Path $awsExecutable)) {
        throw "AWS CLI was not found on PATH or at '$awsExecutable'. Install AWS CLI v2 or add it to PATH."
    }
}

while ((Get-Date) -lt $deadline) {
    $response = & $awsExecutable ec2 get-console-output `
        --instance-id $InstanceId `
        --latest `
        --region $Region `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Could not read the image builder console output. Check AWS credentials and ec2:GetConsoleOutput permission."
    }

    $consoleOutput = ($response | ConvertFrom-Json).Output
    if ($consoleOutput) {
        try {
            $consoleText = [System.Text.Encoding]::UTF8.GetString(
                [System.Convert]::FromBase64String($consoleOutput)
            )
        }
        catch {
            $consoleText = $consoleOutput
        }

        if ($consoleText.Contains("CLIENTA_IMAGE_BUILD_FAILED=")) {
            throw "Image builder bootstrap reported a failure. Inspect /var/log/clienta-image-build.log through the EC2 console output or system log."
        }

        if ($consoleText.Contains("CLIENTA_IMAGE_BUILD_READY")) {
            Write-Output "Image builder bootstrap completed."
            exit 0
        }
    }

    Start-Sleep -Seconds 15
}

throw "Timed out waiting 20 minutes for the image builder. Do not create the AMI until bootstrap is confirmed complete."
