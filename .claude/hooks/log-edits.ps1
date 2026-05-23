# PostToolUse Hook: Log every successful Edit/Write/NotebookEdit
#
# 仅记录，不阻塞。把改动写到 .claude/logs/edits.log，方便事后审计。

$ErrorActionPreference = 'SilentlyContinue'

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }

$logDir = Join-Path $env:CLAUDE_PROJECT_DIR '.claude\logs'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$logFile = Join-Path $logDir 'edits.log'
$ts      = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$tool    = $payload.tool_name
$file    = $payload.tool_input.file_path

$line = "[$ts] $tool  $file"
Add-Content -Path $logFile -Value $line -Encoding utf8

exit 0
