# install.ps1 — superpowers-adversarial-review 安装脚本
# 兼容 PowerShell 5.1+
# 功能：将 adversarial-review-gates skill（含 agents）安装到 ~/.claude/skills/

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── 路径定义 ──────────────────────────────────────────────────────
$ClaudeDir    = Join-Path $env:USERPROFILE '.claude'
$SkillsDir    = Join-Path $ClaudeDir 'skills'
$TargetDir    = Join-Path $SkillsDir 'adversarial-review-gates'
$ScriptRoot   = $PSScriptRoot

# 源文件
$SrcAgents    = Join-Path $ScriptRoot 'agents'
$SrcSkillMd   = Join-Path $ScriptRoot 'SKILL.md'
$SrcSyncMd    = Join-Path $ScriptRoot 'sync.md'

# ── 前置检查 ──────────────────────────────────────────────────────
Write-Host '=== superpowers-adversarial-review 安装程序 ===' -ForegroundColor Cyan
Write-Host ''

# 检查 superpowers 插件是否已安装（plugin cache）
$SuperpowersCachePath = Join-Path $ClaudeDir 'plugins\cache\claude-plugins-official\superpowers'
if (Test-Path $SuperpowersCachePath) {
    $Versions = Get-ChildItem -Path $SuperpowersCachePath -Directory | Sort-Object Name -Descending
    if ($Versions.Count -gt 0) {
        Write-Host "[OK] 已检测到 superpowers 插件 (版本: $($Versions[0].Name))" -ForegroundColor Green
    } else {
        Write-Host '[WARN] superpowers 目录存在但无版本缓存' -ForegroundColor Yellow
    }
} else {
    Write-Host '[WARN] 未检测到 superpowers 插件缓存，sync 将在首次调用 skill 时自动搜索' -ForegroundColor Yellow
}

# ── 备份（如果已有旧版安装） ─────────────────────────────────────
if (Test-Path $TargetDir) {
    $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $BackupDir = Join-Path $ClaudeDir "adversarial-review-gates-backup-$Timestamp"
    Write-Host ''
    Write-Host "正在备份现有安装到: $BackupDir" -ForegroundColor Yellow
    Copy-Item -Path $TargetDir -Destination $BackupDir -Recurse -Force
    Write-Host '[OK] 备份完成' -ForegroundColor Green
}

# ── 安装 skill ────────────────────────────────────────────────────
Write-Host ''
Write-Host '正在安装 adversarial-review-gates skill...' -ForegroundColor Yellow

# 创建目标目录
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

# 复制 SKILL.md 和 sync.md
Copy-Item -Path $SrcSkillMd -Destination (Join-Path $TargetDir 'SKILL.md') -Force
Write-Host '  + SKILL.md' -ForegroundColor DarkGray
Copy-Item -Path $SrcSyncMd -Destination (Join-Path $TargetDir 'sync.md') -Force
Write-Host '  + sync.md' -ForegroundColor DarkGray

# 复制 agents/ 目录
$AgentsTargetDir = Join-Path $TargetDir 'agents'
if (-not (Test-Path $AgentsTargetDir)) {
    New-Item -ItemType Directory -Path $AgentsTargetDir -Force | Out-Null
}

$AgentFiles = Get-ChildItem -Path $SrcAgents -File -Filter '*.md'
$AgentCount = 0

foreach ($agent in $AgentFiles) {
    Copy-Item -Path $agent.FullName -Destination (Join-Path $AgentsTargetDir $agent.Name) -Force
    $AgentCount++
    Write-Host "  + agents/$($agent.Name)" -ForegroundColor DarkGray
}

Write-Host "[OK] 已安装 skill + $AgentCount 个 agent 定义" -ForegroundColor Green

# ── 清理旧版安装的 agent 文件（从 ~/.claude/agents/ 迁移） ────────
$OldAgentsDir = Join-Path $ClaudeDir 'agents'
$OldAgentNames = @(
    'requirement-analyzer.md',
    'technical-designer.md',
    'plan-reviewer.md',
    'design-sync.md',
    'code-reviewer.md',
    'code-verifier.md',
    'security-reviewer.md',
    'test-reviewer.md'
)
$CleanedCount = 0
foreach ($name in $OldAgentNames) {
    $oldPath = Join-Path $OldAgentsDir $name
    if (Test-Path $oldPath) {
        Remove-Item $oldPath -Force -Confirm:$false
        $CleanedCount++
    }
}
if ($CleanedCount -gt 0) {
    Write-Host "[OK] 已清理旧版 $CleanedCount 个 agent 文件 (从 ~/.claude/agents/)" -ForegroundColor Green
}

# ── 安装结果摘要 ──────────────────────────────────────────────────
Write-Host ''
Write-Host '=== 安装完成 ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "  安装位置: $TargetDir" -ForegroundColor White
Write-Host "  文件: SKILL.md, sync.md, agents/ ($AgentCount 个)" -ForegroundColor White
Write-Host ''
Write-Host '下一步: 在 Claude Code 中调用 /adversarial-review-gates 触发首次 sync，' -ForegroundColor Yellow
Write-Host '        自动向 superpowers skill 文件注入显式触发行。' -ForegroundColor Yellow
Write-Host ''
Write-Host '卸载方法: 删除 ~/.claude/skills/adversarial-review-gates/ 目录即可。' -ForegroundColor DarkGray
