# install.ps1 — superpowers-adversarial-review 安装脚本
# 兼容 PowerShell 5.1+
# 功能：将自定义 subagent 定义和修改后的 superpowers skill 文件安装到 ~/.claude/

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── 路径定义 ──────────────────────────────────────────────────────
$ClaudeDir    = Join-Path $env:USERPROFILE '.claude'
$AgentsDir    = Join-Path $ClaudeDir 'agents'
$SkillsDir    = Join-Path $ClaudeDir 'skills'
$ScriptRoot   = $PSScriptRoot  # 安装包所在目录

# 源文件目录
$SrcAgents    = Join-Path $ScriptRoot 'agents'
$SrcSkills    = Join-Path $ScriptRoot 'skill-patches'

# ── 前置检查 ──────────────────────────────────────────────────────
Write-Host '=== superpowers-adversarial-review 安装程序 ===' -ForegroundColor Cyan
Write-Host ''

# 检查 superpowers 插件是否已安装
$SuperpowersMarker = Join-Path $SkillsDir 'using-superpowers' 'SKILL.md'
if (-not (Test-Path $SuperpowersMarker)) {
    Write-Host '[ERROR] 未检测到 superpowers 插件。' -ForegroundColor Red
    Write-Host '请先安装 superpowers：https://github.com/superpowers-ai/superpowers' -ForegroundColor Yellow
    Write-Host "期望文件: $SuperpowersMarker" -ForegroundColor DarkGray
    exit 1
}
Write-Host '[OK] 已检测到 superpowers 插件' -ForegroundColor Green

# ── 备份 ──────────────────────────────────────────────────────────
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path $ClaudeDir "skills-backup-$Timestamp"

Write-Host ''
Write-Host "正在备份现有 skill 文件到: $BackupDir" -ForegroundColor Yellow

# 收集需要备份的 skill 文件（仅备份即将被覆盖的文件）
$SkillPatches = Get-ChildItem -Path $SrcSkills -Recurse -File
$BackedUpCount = 0

foreach ($patch in $SkillPatches) {
    # 计算相对路径（相对于 skill-patches 目录）
    $RelPath = $patch.FullName.Substring($SrcSkills.Length + 1)
    $TargetFile = Join-Path $SkillsDir $RelPath

    if (Test-Path $TargetFile) {
        # 在备份目录中创建对应的子目录
        $BackupFile = Join-Path $BackupDir $RelPath
        $BackupSubDir = Split-Path $BackupFile -Parent
        if (-not (Test-Path $BackupSubDir)) {
            New-Item -ItemType Directory -Path $BackupSubDir -Force | Out-Null
        }
        Copy-Item -Path $TargetFile -Destination $BackupFile -Force
        $BackedUpCount++
    }
}

if ($BackedUpCount -gt 0) {
    Write-Host "[OK] 已备份 $BackedUpCount 个文件" -ForegroundColor Green
} else {
    Write-Host '[INFO] 无需备份（目标文件均不存在）' -ForegroundColor DarkGray
    # 如果没有文件需要备份，删除空的备份目录
    if (Test-Path $BackupDir) {
        Remove-Item -Path $BackupDir -Recurse -Force -Confirm:$false
    }
}

# ── 安装 agents ───────────────────────────────────────────────────
Write-Host ''
Write-Host '正在安装 agent 定义文件...' -ForegroundColor Yellow

# 确保 agents 目录存在
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

# ── 安装 skill patches ───────────────────────────────────────────
Write-Host ''
Write-Host '正在安装 skill patch 文件...' -ForegroundColor Yellow

$PatchCount = 0

foreach ($patch in $SkillPatches) {
    $RelPath = $patch.FullName.Substring($SrcSkills.Length + 1)
    $TargetFile = Join-Path $SkillsDir $RelPath
    $TargetSubDir = Split-Path $TargetFile -Parent

    # 确保目标子目录存在
    if (-not (Test-Path $TargetSubDir)) {
        New-Item -ItemType Directory -Path $TargetSubDir -Force | Out-Null
    }

    Copy-Item -Path $patch.FullName -Destination $TargetFile -Force
    $PatchCount++
    Write-Host "  + $RelPath" -ForegroundColor DarkGray
}

Write-Host "[OK] 已安装 $PatchCount 个 skill patch" -ForegroundColor Green

# ── 安装结果摘要 ──────────────────────────────────────────────────
Write-Host ''
Write-Host '=== 安装完成 ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "  Agent 定义:     $AgentCount 个文件 -> $AgentsDir" -ForegroundColor White
Write-Host "  Skill Patch:    $PatchCount 个文件 -> $SkillsDir" -ForegroundColor White
if ($BackedUpCount -gt 0) {
    Write-Host "  备份位置:       $BackupDir" -ForegroundColor White
}
Write-Host ''
Write-Host '卸载方法: 从备份目录恢复原始文件，删除 agents/ 下的 8 个 agent 文件。' -ForegroundColor DarkGray
Write-Host '详见 README.md 中的卸载说明。' -ForegroundColor DarkGray
