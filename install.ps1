$ErrorActionPreference = "Stop"

$ServerUrl = "http://62.201.217.54:8082"
$InstallerUrl = "https://github.com/AkarAhmaad/netinventory-agent-installer/releases/download/v1.4.18/NetInventoryAgent-1.4.18.exe"
$ExpectedSha256 = "E0A86EA9E8D56490988D0F4B71D4BB4C0C270E1419AFED4EB78800D419BD3994"
$InstallDir = "$env:ProgramFiles\NetInventory\Agent"
$BootstrapDir = "$env:ProgramData\NetInventoryAgent\bootstrap"
$InstallerPath = Join-Path $BootstrapDir "NetInventoryAgent-1.4.18.exe"

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Please run PowerShell as Administrator."
    }
}

function Set-SafeAcl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [switch]$AllowUsersRead
    )

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    if ($AllowUsersRead) {
        & icacls.exe $Path /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-32-545:(OI)(CI)RX" /T /C | Out-Null
    } else {
        & icacls.exe $Path /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" /T /C | Out-Null
    }
}

function Add-NetInventoryDefenderExclusion {
    if (-not (Get-Command Add-MpPreference -ErrorAction SilentlyContinue)) {
        Write-Warning "Microsoft Defender cmdlets are not available. Skipping Defender exclusion."
        return
    }

    try { Add-MpPreference -ExclusionPath $InstallDir -ErrorAction Stop } catch { Write-Warning $_.Exception.Message }
    try { Add-MpPreference -ExclusionPath $BootstrapDir -ErrorAction Stop } catch { Write-Warning $_.Exception.Message }
    try { Add-MpPreference -ExclusionProcess (Join-Path $InstallDir "NetInventoryAgent.exe") -ErrorAction Stop } catch { Write-Warning $_.Exception.Message }
}

Assert-Administrator
Set-SafeAcl -Path $BootstrapDir
Set-SafeAcl -Path $InstallDir -AllowUsersRead
Add-NetInventoryDefenderExclusion

Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath -UseBasicParsing

$actualSha256 = (Get-FileHash $InstallerPath -Algorithm SHA256).Hash.ToUpperInvariant()
if ($actualSha256 -ne $ExpectedSha256) {
    throw "Installer SHA256 mismatch. Expected $ExpectedSha256 but got $actualSha256."
}

$process = Start-Process -FilePath $InstallerPath -ArgumentList "/S /SERVERURL=$ServerUrl" -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "Installer failed with exit code $($process.ExitCode)."
}

Start-Service NetInventoryAgent -ErrorAction SilentlyContinue
Write-Host "NetInventory Agent 1.4.18 installed successfully."
