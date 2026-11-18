# Build a private, complete Reborn planner recipe using YOUR local executable.
# Never edits the game installation; no upload or publication.
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$GameRoot,
  [string]$GameExe = ""
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$game = (Resolve-Path -LiteralPath $GameRoot).Path
$native = Join-Path $game "Interface\AddOns"
if (!(Test-Path -LiteralPath (Join-Path $native "AzerothSurvivors") -PathType Container)) {
  throw "No native AzerothSurvivors in $native. Point GameRoot at the Reborn installation."
}
if (!$GameExe) {
  $exe = @(Get-ChildItem -LiteralPath $game -Filter "*.exe" -File -Recurse |
    Where-Object { $_.Name -match '(?i)Azeroth|Survivors|Reborn' })
  if ($exe.Count -ne 1) {
    Write-Host "Executable candidates found:" -ForegroundColor Yellow
    $exe | ForEach-Object { Write-Host $_.FullName }
    throw "Please pass -GameExe with the exact installed Reborn executable path."
  }
  $GameExe = $exe[0].FullName
}
$GameExe = (Resolve-Path -LiteralPath $GameExe).Path
if (!$GameExe.StartsWith($game, [StringComparison]::OrdinalIgnoreCase)) {
  throw "GameExe must come from GameRoot."
}
Set-Location $root
$python = (Get-Command python -ErrorAction Stop).Source
$venv = Join-Path $root ".devtools\venv\Scripts\python.exe"
if (!(Test-Path -LiteralPath $venv)) {
  Write-Host "Setting up isolated test venv (no change to game)" -ForegroundColor Cyan
  & $python -m venv (Join-Path $root ".devtools\venv")
  if ($LASTEXITCODE -ne 0) { throw "venv creation failed" }
  & $venv -m pip install "lupa==2.8" "Pillow"
  if ($LASTEXITCODE -ne 0) { throw "lupa installation failed" }
}
if (!(Test-Path -LiteralPath $venv)) { throw "venv not ready" }
# Existing venvs created for earlier lots may have lupa but not Pillow.
# Verify both libraries every time before generating textures; install only missing ones.
& $venv -I -c "import lupa; from PIL import Image"
if ($LASTEXITCODE -ne 0) {
  Write-Host "Installing missing isolated Lua/Pillow build dependencies" -ForegroundColor Cyan
  & $venv -m pip install "lupa==2.8" "Pillow"
  if ($LASTEXITCODE -ne 0) { throw "Unable to install required Python build dependencies" }
  & $venv -I -c "import lupa; from PIL import Image"
  if ($LASTEXITCODE -ne 0) { throw "Lua/Pillow verification failed after installation" }
}
$python = $venv
Write-Host "Retrieving official public Reborn data into the ignored .local folder" -ForegroundColor Cyan
$catalog = Join-Path $root ".local\catalog\public-preview"
& $python -I tools/fetch_catalog_public.py --out $catalog
if ($LASTEXITCODE -ne 0) { throw "Public catalogue retrieval failed" }
$env:RBP_CATALOG_DIR = $catalog
& $python -I tools/generate_catalog.py
if ($LASTEXITCODE -ne 0) { throw "Catalogue generator refused current schema" }
Write-Host "Running the full strict recipe (Lua tests, native contracts, local metadata)" -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "tools\recette_ultimate_windows.ps1") -GameExe $GameExe -CatalogDir $catalog -NativeRoot $native -OutputDir (Join-Path $root "dist\ultimate-0.4.10-local")
if ($LASTEXITCODE -ne 0) { throw "Recipe refused; no verified build produced" }
Write-Host "LOCAL 0.4.10 PACKAGE BUILT. Game files and SavedVariables unchanged." -ForegroundColor Green
