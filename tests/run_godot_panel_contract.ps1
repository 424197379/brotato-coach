param(
  [string]$GodotPath = $env:GODOT_3_6_EXE
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
  $GodotPath = "D:\DevelopEnvironment\ModDevelop\Godot\3.6.1-stable\Godot_v3.6.1-stable_win64.exe"
}
$Godot = $GodotPath
$ProjectDir = Join-Path $Root "tests\godot_cli"
$ReportDir = Join-Path $Root "private\dev-docs\test-reports\godot-panel-contract"
$PanelSource = Join-Path $Root "src\brotato-mod\BrotatoCoach-BrotatoCoach\ui\coach_report_panel.gd"
$EngineSource = Join-Path $Root "src\brotato-mod\BrotatoCoach-BrotatoCoach\core\offline_rule_engine.gd"
$PanelUnderTest = Join-Path $ProjectDir "coach_report_panel_under_test.gd"
$Runner = Join-Path $ProjectDir "panel_contract_runner.gd"

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

if (-not (Test-Path -LiteralPath $Godot)) {
  $summary = [pscustomobject]@{
    godot = $Godot
    project_dir = $ProjectDir
    copied_panel = $PanelUnderTest
    results = @()
    passed = $true
    skipped = $true
    skip_reason = "Godot executable not found; panel contract requires a local Godot 3.6 executable."
  }
  $summaryPath = Join-Path $ReportDir "summary.json"
  $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
  Write-Output "Godot panel contract skipped. Summary: $summaryPath"
  Write-Output $summary.skip_reason
  exit 0
}

Copy-Item -LiteralPath $PanelSource -Destination $PanelUnderTest -Force

function Invoke-GodotCommand {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string[]]$Arguments
  )

  $stdout = Join-Path $ReportDir "$Name.stdout.txt"
  $stderr = Join-Path $ReportDir "$Name.stderr.txt"
  $process = Start-Process -FilePath $Godot `
    -ArgumentList $Arguments `
    -WorkingDirectory $ProjectDir `
    -NoNewWindow `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr

  $hasScriptError = $false
  if (Test-Path -LiteralPath $stderr) {
    $hasScriptError = [bool](Select-String -LiteralPath $stderr -Pattern "(?i)(SCRIPT ERROR|Parse Error|ERROR:)" -Quiet)
  }

  [pscustomobject]@{
    name = $Name
    exit_code = $process.ExitCode
    has_script_error = $hasScriptError
    arguments = $Arguments
    stdout = $stdout
    stderr = $stderr
  }
}

$results = @()
$results += Invoke-GodotCommand -Name "check_panel" -Arguments @("--no-window", "--check-only", "--script", $PanelSource)
$results += Invoke-GodotCommand -Name "check_engine" -Arguments @("--no-window", "--check-only", "--script", $EngineSource)
$results += Invoke-GodotCommand -Name "panel_contract" -Arguments @("--no-window", "--path", $ProjectDir, "--script", $Runner)

$summary = [pscustomobject]@{
  godot = $Godot
  project_dir = $ProjectDir
  copied_panel = $PanelUnderTest
  results = $results
  passed = -not ($results | Where-Object { $_.exit_code -ne 0 -or $_.has_script_error })
  skipped = $false
  skip_reason = ""
}

$summaryPath = Join-Path $ReportDir "summary.json"
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

if (-not $summary.passed) {
  Write-Output "Godot panel contract failed. Summary: $summaryPath"
  foreach ($result in $results) {
    Write-Output ("{0}: exit {1}, script_error {2}" -f $result.name, $result.exit_code, $result.has_script_error)
    if (Test-Path -LiteralPath $result.stderr) {
      Get-Content -LiteralPath $result.stderr -Tail 40
    }
  }
  exit 1
}

Write-Output "Godot panel contract passed. Summary: $summaryPath"
exit 0
