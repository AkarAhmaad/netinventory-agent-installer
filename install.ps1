$ErrorActionPreference = "Stop"
$u = "https://github.com/AkarAhmaad/netinventory-agent-installer/releases/download/v1.4.14/NetInventoryAgent-1.4.14.exe"
$f = "$env:TEMP\NetInventoryAgent-1.4.14.exe"

Remove-Item $f -Force -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing

$p = Start-Process -FilePath $f -ArgumentList "/S /SERVERURL=http://62.201.217.54:8082" -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Installer failed with exit code $($p.ExitCode)" }

Start-Service NetInventoryAgent -ErrorAction SilentlyContinue
Write-Host "NetInventory Agent installed successfully."
