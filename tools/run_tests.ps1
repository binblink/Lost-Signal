#!/usr/bin/env pwsh
# Resolve Godot from GODOT_BIN, PATH, or a standard standalone download in Documents.
$godot = $env:GODOT_BIN

if (-not $godot) {
	$command = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($command) { $godot = $command.Source }
}

if (-not $godot) {
	$documents = [Environment]::GetFolderPath('MyDocuments')
	$candidate = Get-ChildItem -Path $documents -Filter 'Godot_v*-stable_win64.exe' -ErrorAction SilentlyContinue |
		Sort-Object Name -Descending |
		Select-Object -First 1
	if ($candidate) {
		if ($candidate.PSIsContainer) {
			$inner = Join-Path $candidate.FullName $candidate.Name
			if (Test-Path -LiteralPath $inner -PathType Leaf) { $godot = $inner }
		} else {
			$godot = $candidate.FullName
		}
	}
}

if (-not $godot -or -not (Test-Path -LiteralPath $godot -PathType Leaf)) {
	Write-Error 'Godot was not found. Set GODOT_BIN or add godot/godot4 to PATH.'
	exit 1
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path ([System.IO.Path]::GetTempPath()) ("lost-signal-tests-{0}.log" -f [guid]::NewGuid())
Push-Location $projectRoot
& $godot --headless --path "$PWD" --log-file $logPath --script res://tools/tests/run_tests.gd
$exitCode = $LASTEXITCODE
Pop-Location

$combinedOutput = Get-Content -Raw -LiteralPath $logPath -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
if ($combinedOutput -match 'SCRIPT ERROR:|Failed to load script|CrashHandlerException|\[FAIL\]|Some tests failed\.') {
	exit 1
}
exit $exitCode
