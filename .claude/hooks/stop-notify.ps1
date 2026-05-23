# Stop Hook: Claude 主对话回合结束时触发
#
# 典型用途：长任务跑完桌面提醒、写入审计日志、把"本回合摘要"推到 Slack。
# 本演示只往 .claude/logs/stop.log 写一条记录，避免弹窗骚扰。

$ErrorActionPreference = 'SilentlyContinue'

$raw = [Console]::In.ReadToEnd()
try { $payload = $raw | ConvertFrom-Json } catch { $payload = $null }

$logDir = Join-Path $env:CLAUDE_PROJECT_DIR '.claude\logs'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$logFile = Join-Path $logDir 'stop.log'
$ts      = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$sid     = if ($payload) { $payload.session_id } else { '<no-session>' }

Add-Content -Path $logFile -Value "[$ts] Stop event  session=$sid" -Encoding utf8

# 若需要桌面通知，取消下面这行注释（Windows 10/11 BurntToast 模块）：
# New-BurntToastNotification -Text 'Claude Code', "Session $sid finished."

exit 0
