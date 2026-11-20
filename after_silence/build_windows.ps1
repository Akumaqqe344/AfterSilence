param([string]$Godot='C:\Games\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe',[switch]$SkipTests)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot executable missing: $Godot" }
New-Item -ItemType Directory -Force -Path work,after_silence/build | Out-Null
function Invoke-CheckedGodot([string]$Log,[string[]]$EngineArgs) {
    & $Godot @EngineArgs *> $Log
    if ($LASTEXITCODE -ne 0) { throw "Godot exit $LASTEXITCODE; see $Log" }
    if (Select-String -LiteralPath $Log -Pattern 'SCRIPT ERROR:|Parser Error|ERROR:|Invalid call|Cannot convert|is_inside_tree|failing tests|ObjectDB.*leaked|orphan nodes' -Quiet) { throw "Godot reported errors; see $Log" }
}
Invoke-CheckedGodot 'work/import-release.log' @('--headless','--editor','--path','.','--import')
if (-not $SkipTests) {
	Invoke-CheckedGodot 'work/pixel-world-test.log' @('--headless','--path','.','--','--qa','--qa-pixel-export')
	Invoke-CheckedGodot 'work/ui-comfort-test.log' @('--headless','--path','.','--','--qa','--qa-ui-export')
    Invoke-CheckedGodot 'work/npc-routes-test.log' @('--headless','--path','.','--script','after_silence/tests/run_npc_routes.gd','--','--qa')
    Invoke-CheckedGodot 'work/journey140-test.log' @('--headless','--path','.','--script','after_silence/tests/run_journey140.gd','--','--qa')
    Invoke-CheckedGodot 'work/quiet-puzzles-test.log' @('--headless','--path','.','--script','after_silence/tests/run_quiet_puzzles.gd','--','--qa')
    Invoke-CheckedGodot 'work/events-migration-test.log' @('--headless','--path','.','--','--qa','--qa-events-export')
    Invoke-CheckedGodot 'work/landscape120-test.log' @('--headless','--path','.','--script','after_silence/tests/run_landscape120.gd','--','--qa')
    Invoke-CheckedGodot 'work/merge110-test.log' @('--headless','--path','.','--script','after_silence/tests/run_merge110.gd','--','--qa')
    Invoke-CheckedGodot 'work/gut-all.log' @('--headless','--path','.','-s','addons/gut/gut_cmdln.gd','-gdir=res://test/unit/,res://after_silence/tests/','-gexit')
    Invoke-CheckedGodot 'work/episode-test.log' @('--headless','--path','.','--script','after_silence/tests/run_episode.gd','--','--qa')
    Invoke-CheckedGodot 'work/rift-test.log' @('--headless','--path','.','--script','after_silence/tests/run_rift.gd','--','--qa')
    Invoke-CheckedGodot 'work/adventure-test.log' @('--headless','--path','.','--script','after_silence/tests/run_adventure.gd','--','--qa')
    Invoke-CheckedGodot 'work/living-test.log' @('--headless','--path','.','--script','after_silence/tests/run_living_world.gd','--','--qa')
    Invoke-CheckedGodot 'work/visual-fix-test.log' @('--headless','--path','.','--script','after_silence/tests/run_visual_fix091.gd','--','--qa')
    Invoke-CheckedGodot 'work/art-audit-test.log' @('--headless','--path','.','--script','after_silence/tests/run_art_audit.gd','--','--qa')
}
Copy-Item -LiteralPath after_silence/export_windows.cfg -Destination export_presets.cfg -Force
Invoke-CheckedGodot 'work/export-windows.log' @('--headless','--path','.','--export-release','After Silence Windows','after_silence/build/AfterSilence.exe')
Get-Item -LiteralPath after_silence/build/AfterSilence.exe | Select-Object FullName,Length
$binaryHash=Get-FileHash -Algorithm SHA256 -LiteralPath after_silence/build/AfterSilence.exe
Write-Output "SHA256=$($binaryHash.Hash)"
