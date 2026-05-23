# PreToolUse Hook: Block dangerous Bash commands
#
# Hook 协议：
#   - 输入：stdin 接收 JSON，包含 tool_name / tool_input / session_id 等
#   - 输出：stdout 写 JSON，决定是否放行；exit code 也影响行为：
#       exit 0  → 默认放行（stdout 的 JSON 可改判定）
#       exit 2  → 阻塞，并把 stderr 作为错误反馈给模型
#
# 本脚本：检查 Bash 命令里的危险模式，命中就 deny。

$ErrorActionPreference = 'Stop'

# 读取 stdin（Claude Code 注入的 JSON 输入）
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

try {
    $payload = $raw | ConvertFrom-Json
} catch {
    # 协议异常就放行，不要因为脚本 bug 卡死正常工作
    exit 0
}

if ($payload.tool_name -ne 'Bash') { exit 0 }

$cmd = [string]$payload.tool_input.command
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

# 黑名单正则
$patterns = @(
    '\brm\s+-rf\s+/',          # rm -rf /
    'mkfs\.',                   # 格式化分区
    ':\(\)\s*\{.*\}\s*;:',      # fork bomb
    '\bdd\s+if=.*of=/dev/'      # 写裸设备
)

foreach ($p in $patterns) {
    if ($cmd -match $p) {
        $resp = @{
            hookSpecificOutput = @{
                hookEventName    = 'PreToolUse'
                permissionDecision = 'deny'
                permissionDecisionReason = "block-dangerous.ps1: 命中黑名单模式 '$p'"
            }
        } | ConvertTo-Json -Depth 5 -Compress
        [Console]::Out.WriteLine($resp)
        exit 0
    }
}

# 未命中，正常放行
exit 0
