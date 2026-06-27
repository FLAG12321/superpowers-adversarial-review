# install.ps1 — superpowers-adversarial-review 安装脚本
# 兼容 PowerShell 5.1+
# 功能：将 adversarial-review-gates skill 安装到 ~/.claude/skills/，agent 定义安装到 ~/.claude/agents/

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── 路径定义 ──────────────────────────────────────────────────────
$ClaudeDir    = Join-Path $env:USERPROFILE '.claude'
$SkillsDir    = Join-Path $ClaudeDir 'skills'
$AgentsDir    = Join-Path $ClaudeDir 'agents'
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

# 创建 skill 目录
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

# 复制 SKILL.md 和 sync.md
Copy-Item -Path $SrcSkillMd -Destination (Join-Path $TargetDir 'SKILL.md') -Force
Write-Host '  + SKILL.md' -ForegroundColor DarkGray
Copy-Item -Path $SrcSyncMd -Destination (Join-Path $TargetDir 'sync.md') -Force
Write-Host '  + sync.md' -ForegroundColor DarkGray

Write-Host '[OK] 已安装 skill 文件' -ForegroundColor Green

# ── 安装 agents ───────────────────────────────────────────────────
Write-Host ''
Write-Host '正在安装 agent 定义到 ~/.claude/agents/...' -ForegroundColor Yellow

if (-not (Test-Path $AgentsDir)) {
    New-Item -ItemType Directory -Path $AgentsDir -Force | Out-Null
}

$AgentFiles = Get-ChildItem -Path $SrcAgents -File -Filter '*.md'
$AgentCount = 0

foreach ($agent in $AgentFiles) {
    Copy-Item -Path $agent.FullName -Destination (Join-Path $AgentsDir $agent.Name) -Force
    $AgentCount++
    Write-Host "  + $($agent.Name)" -ForegroundColor DarkGray
}

Write-Host "[OK] 已安装 $AgentCount 个 agent 定义" -ForegroundColor Green

# ── 安装结果摘要 ──────────────────────────────────────────────────
Write-Host ''
Write-Host '=== 安装完成 ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "  Skill:   $TargetDir" -ForegroundColor White
Write-Host "           SKILL.md, sync.md" -ForegroundColor White
Write-Host "  Agents:  $AgentsDir" -ForegroundColor White
Write-Host "           $AgentCount 个 agent 定义" -ForegroundColor White
Write-Host ''
Write-Host '下一步: 在 Claude Code 中调用 /adversarial-review-gates 触发首次 sync，' -ForegroundColor Yellow
Write-Host '        自动向 superpowers skill 文件注入显式触发行。' -ForegroundColor Yellow
Write-Host ''
Write-Host '卸载: 删除 ~/.claude/skills/adversarial-review-gates/ 和 ~/.claude/agents/ 下的 8 个 agent 文件。' -ForegroundColor DarkGray
