param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ModId = "BrotatoCoach-BrotatoCoach"
$ZipName = "BrotatoCoach"
$SourceDir = Join-Path $ProjectRoot "src\brotato-mod\$ModId"
$RuleSource = Join-Path $ProjectRoot "data\rules"
$BuildRoot = Join-Path $ProjectRoot "src\brotato-mod\build"
$StageDir = Join-Path $BuildRoot "mods-unpacked\$ModId"
$DistDir = Join-Path $ProjectRoot "src\brotato-mod\dist"
$ZipPath = Join-Path $DistDir "$ZipName.zip"

if (!(Test-Path $SourceDir)) {
    throw "Mod source not found: $SourceDir"
}
if (!(Test-Path $RuleSource)) {
    throw "Rule source not found: $RuleSource"
}

New-Item -ItemType Directory -Force $BuildRoot, $DistDir | Out-Null

$ResolvedBuildRoot = (Resolve-Path $BuildRoot).Path
if (Test-Path $BuildRoot) {
    $ResolvedStageRoot = (Resolve-Path $BuildRoot).Path
    if (!$ResolvedStageRoot.EndsWith("src\brotato-mod\build", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean unexpected build root: $ResolvedStageRoot"
    }
    Get-ChildItem -LiteralPath $BuildRoot -Force | Remove-Item -Recurse -Force
}

New-Item -ItemType Directory -Force $StageDir | Out-Null
Copy-Item -Path (Join-Path $SourceDir "*") -Destination $StageDir -Recurse -Force
New-Item -ItemType Directory -Force (Join-Path $StageDir "rules") | Out-Null
Copy-Item -LiteralPath (Join-Path $RuleSource "rule-pack-0.1.0.json") -Destination (Join-Path $StageDir "rules\rule-pack-0.1.0.json") -Force

if (Test-Path $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
}

# Compress-Archive writes Windows path separators into ZIP entry names. Godot
# ModLoader validates portable ZIP paths and rejects those archives.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open(
    $ZipPath,
    [System.IO.Compression.ZipArchiveMode]::Create
)
try {
    Get-ChildItem -LiteralPath $BuildRoot -Recurse -File | ForEach-Object {
        $entryName = $_.FullName.Substring($ResolvedBuildRoot.Length).TrimStart("\", "/").Replace("\", "/")
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive,
            $_.FullName,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $archive.Dispose()
}

if (Test-Path $StageDir) {
    $ResolvedStage = (Resolve-Path $StageDir).Path
    if (!$ResolvedStage.StartsWith($ResolvedBuildRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove stage outside build root after packaging: $ResolvedStage"
    }
    Remove-Item -LiteralPath $ResolvedStage -Recurse -Force
}

Write-Output $ZipPath
