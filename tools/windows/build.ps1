param(
    [string]$Godot,
    [string]$OutputDir = (Join-Path $PSScriptRoot '..\..\after_silence\build\windows')
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$version = '4.7.2'
$cache = Join-Path $env:LOCALAPPDATA "AfterSilenceBuild\Godot\$version"
$templates = Join-Path $env:APPDATA "Godot\export_templates\$version.stable"
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Install-GodotFiles($Platform, $Slug, $Destination, $Entries) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    $download = Join-Path ([IO.Path]::GetTempPath()) ("after-silence-" + [guid]::NewGuid() + ".zip")
    try {
        Write-Host "Downloading Godot $version ($Platform)..."
        $url = "https://downloads.godotengine.org/?flavor=stable&platform=$Platform&slug=$Slug&version=$version"
        Invoke-WebRequest -Uri $url -OutFile $download -UseBasicParsing -TimeoutSec 300
        $archive = [IO.Compression.ZipFile]::OpenRead($download)
        try {
            foreach ($name in $Entries) {
                $entry = $archive.GetEntry($name)
                if (-not $entry -or -not $entry.Length) { throw "Missing download entry: $name" }
                $file = Join-Path $Destination $entry.Name
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, "$file.partial", $true)
                Move-Item -LiteralPath "$file.partial" -Destination $file -Force
            }
        } finally { $archive.Dispose() }
    } finally {
        if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download -Force }
    }
}

if ($Godot) {
    $Godot = (Resolve-Path -LiteralPath $Godot).Path
} else {
    $prefix = "Godot_v$version-stable_win64"
    $Godot = Join-Path $cache "$($prefix)_console.exe"
    if (-not (Test-Path -LiteralPath $Godot)) {
        Install-GodotFiles 'windows.64' 'win64.exe.zip' $cache @("$prefix.exe", "$($prefix)_console.exe")
    }
}
$identity = & $Godot --version
if ($LASTEXITCODE -ne 0 -or "$identity" -notmatch ('^' + [regex]::Escape($version) + '\.stable(\.|$)')) {
    throw "Select the Godot $version Standard console executable. Found: $identity"
}
if (-not (Test-Path -LiteralPath (Join-Path $templates 'windows_release_x86_64.exe'))) {
    Install-GodotFiles 'templates' 'export_templates.tpz' $templates @('templates/windows_release_x86_64.exe')
}

$destination = (New-Item -ItemType Directory -Path $OutputDir -Force).FullName
$stage = Join-Path $destination ('package-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
    & $Godot --headless --path $root --editor --import
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
    $game = Join-Path $stage 'AfterSilence.exe'
    & $Godot --headless --path $root --export-release 'After Silence Windows' $game
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $game -PathType Leaf) -or
        -not (Get-Item -LiteralPath $game).Length) { throw 'Windows export failed.' }

    foreach ($name in @('Install-AfterSilence.cmd', 'install.ps1')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $stage
    }
    foreach ($name in @('README_RU.md', 'CHANGELOG.md', 'KNOWN_ISSUES.md', 'SAVE_COMPATIBILITY.md', 'BUILD_RU.md')) {
        Copy-Item -LiteralPath (Join-Path $root $name) -Destination $stage
    }

    $licenses = Join-Path $stage 'Licenses'
    New-Item -ItemType Directory -Path $licenses | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $licenses 'Little-Adventure-LICENSE.txt')
    Copy-Item -LiteralPath (Join-Path $root 'after_silence\ASSET_PROVENANCE.md') -Destination $licenses
    Get-ChildItem -LiteralPath (Join-Path $root 'after_silence\third_party') -Filter '*.txt' |
        Copy-Item -Destination $licenses
    Get-ChildItem -LiteralPath (Join-Path $root 'after_silence\assets\fonts') -Filter '*OFL.txt' |
        Copy-Item -Destination $licenses
    foreach ($addon in @('beehave', 'npc_talkkit')) {
        Copy-Item -LiteralPath (Join-Path $root "addons\$addon\LICENSE") -Destination (Join-Path $licenses "$addon-LICENSE.txt")
    }

    $zip = Join-Path $destination 'AfterSilence-windows-x86_64.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, "$stage.zip", [IO.Compression.CompressionLevel]::Optimal, $false)
    Copy-Item -LiteralPath $game -Destination $destination -Force
    Move-Item -LiteralPath "$stage.zip" -Destination $zip -Force
    Write-Host "Windows ZIP: $zip"
} finally {
    if ((Resolve-Path -LiteralPath $stage).Path -eq $stage -and
        (Split-Path -Parent $stage) -eq $destination) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
    if (Test-Path -LiteralPath "$stage.zip") { Remove-Item -LiteralPath "$stage.zip" -Force }
}
