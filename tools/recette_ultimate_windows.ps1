# Reborn Build Planner — Windows recipe (never modifies the game installation).
# Usage:
# powershell -ExecutionPolicy Bypass -File tools\recette_ultimate_windows.ps1 -GameExe "X:\...\Game.exe" -CatalogDir "X:\...\data\v1"
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$GameExe,
  [Parameter(Mandatory=$true)][string]$CatalogDir,
  [string]$OfficialBundle = "",
  [string]$OutputDir = ""
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $root
if (!(Test-Path -LiteralPath $GameExe -PathType Leaf)) { throw "Executable missing: $GameExe" }
if (!(Test-Path -LiteralPath (Join-Path $CatalogDir "jewelry.json") -PathType Leaf)) { throw "Missing official jewelry.json in $CatalogDir" }
if (!(Test-Path -LiteralPath (Join-Path $CatalogDir "index.json") -PathType Leaf)) { throw "Missing index.json in $CatalogDir" }
$python = (Get-Command python -ErrorAction Stop).Source
$venv = Join-Path $root ".devtools\venv\Scripts\python.exe"
if (!(Test-Path -LiteralPath $venv)) { throw "Lua 5.1 venv missing. See README.md: python -m venv .devtools\venv; .devtools\venv\Scripts\python.exe -m pip install lupa" }
if (!$OutputDir) { $OutputDir = Join-Path $root "dist\ultimate-0.4.4-recette" }
$outFull = [IO.Path]::GetFullPath($OutputDir)
$rootFull = [IO.Path]::GetFullPath($root)
if (!$outFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw "OutputDir must remain inside the development project: $root"
}
$env:RBP_GAME_EXE = [IO.Path]::GetFullPath($GameExe)
$env:RBP_CATALOG_DIR = [IO.Path]::GetFullPath($CatalogDir)
if ($OfficialBundle) {
  if (!(Test-Path -LiteralPath $OfficialBundle -PathType Leaf)) { throw "Official bundle not found" }
  $env:RBP_OFFICIAL_BUNDLE = [IO.Path]::GetFullPath($OfficialBundle)
} else {
  Remove-Item Env:RBP_OFFICIAL_BUNDLE -ErrorAction SilentlyContinue
}

Write-Host "1/4 Running read-only tests (Lua 5.1, model, codec, original textures)" -ForegroundColor Cyan
& $python -I tools/run_all.py
$testExit = $LASTEXITCODE
if ($testExit -eq 1) { throw "A test FAILED. Read tests\results\last_run.txt. No ZIP was produced." }
if ($testExit -ne 0 -and $testExit -ne 3) { throw "Unexpected test exit code $testExit" }
$testLog = Get-Content -LiteralPath (Join-Path $root "tests\results\last_run.txt")
if (@($testLog | Where-Object { $_ -match "^== .+: FAIL(?: |$)" }).Count -gt 0) { throw "Test failures recorded. No ZIP was produced." }
$skipped = @($testLog | Where-Object { $_ -match "^== .+: SKIPPED" })
if ($skipped.Count -gt 0) {
  $unexpected = @($skipped | Where-Object { $_ -notmatch "^== JS <-> Lua cross-check" })
  if ($unexpected.Count -gt 0) { throw "Required tests SKIPPED: $($unexpected -join '; ')" }
  Write-Warning "Only optional official JS cross-check was SKIPPED; this is not a verified end-to-end roundtrip."
}
Write-Host "2/4 Packaging with local jewelry metadata (read-only source)" -ForegroundColor Cyan
& $python -I tools/package_addon.py --out $outFull
if ($LASTEXITCODE -ne 0) { throw "Package creation failed; inspect extractor diagnostics" }

$zip = Get-ChildItem -LiteralPath $outFull -Filter "RebornBuildPlanner-*-recette.zip" -File | Select-Object -First 1
if (!$zip) { throw "No addon ZIP in output" }
Write-Host "3/4 Verifying package and expected resources" -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip.FullName)
try {
  $entries = @($archive.Entries | ForEach-Object { $_.FullName })
  $tocEntry = "RebornBuildPlanner/RebornBuildPlanner.toc"
  if ($entries -notcontains $tocEntry) { throw "Missing TOC in ZIP" }
  $tocLines = Get-Content -LiteralPath (Join-Path $root "addon\RebornBuildPlanner\RebornBuildPlanner.toc")
  foreach ($line in $tocLines) {
    $line = $line.Trim()
    if (!$line -or $line.StartsWith("#")) { continue }
    if ($entries -notcontains ("RebornBuildPlanner/" + $line)) { throw "ZIP missing " + $line }
  }
  foreach ($asset in @("ultimate_panel.tga", "ultimate_titlebar.tga", "ultimate_corner.tga", "ultimate_crest.tga")) {
    if ($entries -notcontains ("RebornBuildPlanner/Media/" + $asset)) { throw "ZIP missing fantasy asset " + $asset }
  }
  $localFacts = $archive.GetEntry("RebornBuildPlanner/GeneratedJewelryMechanics.lua")
  if (!$localFacts -or $localFacts.Length -lt 1500) { throw "Locally extracted jewelry metadata absent or suspiciously small" }
} finally { $archive.Dispose() }
Write-Host "4/4 Writing an honest recette manifest" -ForegroundColor Cyan
$manifest = @(
  "# Ultimate UI recette — local generated package"
  ""
  "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
  "Git HEAD: $(git rev-parse HEAD)"
  "Package SHA-256: $((Get-FileHash -LiteralPath $zip.FullName -Algorithm SHA256).Hash)"
  "Test exit: $testExit (0 = all PASS, 3 = optional JS comparison skipped)"
  "Skipped checks: $($skipped.Count)"
  ""
  "Validations performed: model/codec/Lua test runner; local jewelry extraction; archive inventory."
  "NOT performed: live Reborn load, saved-variable reload in the real client, UI visual sign-off."
  "No files in the user's game installation were changed by this script."
)
Set-Content -LiteralPath (Join-Path $outFull "RECETTE_RESULT.md") -Value $manifest -Encoding UTF8
Write-Host "PACKAGE READY FOR IN-GAME RECIPE: $($zip.FullName)" -ForegroundColor Green
