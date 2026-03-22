$ErrorActionPreference = 'Stop'

Write-Host 'Building Flutter Windows release...'
flutter build windows --release

$isccCandidates = @(
    (Get-Command ISCC.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    'C:\Program Files\Inno Setup 6\ISCC.exe',
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) }

if ($isccCandidates.Count -gt 0) {
    $isccPath = @($isccCandidates)[0]
} else {
    Write-Error "Inno Setup compiler (ISCC.exe) not found. Install Inno Setup 6 first: https://jrsoftware.org/isinfo.php"
}

$scriptPath = Join-Path $PSScriptRoot '..\installer\ambigai_bricks_setup.iss'
$scriptPath = (Resolve-Path $scriptPath).Path

Write-Host "Creating installer using: $isccPath"
& $isccPath $scriptPath

Write-Host 'Done. Installer output is in dist\AmbigaiBricksSetup.exe'
