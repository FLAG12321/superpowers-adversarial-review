# install.ps1 — superpowers-adversarial-review installer
# Compatible with PowerShell 5.1+
# Installs adversarial-review-gates skill + sync skill + agent definitions

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Path definitions ─────────────────────────────────────────────
$ClaudeDir    = Join-Path $env:USERPROFILE '.claude'
$SkillsDir    = Join-Path $ClaudeDir 'skills'
$AgentsDir    = Join-Path $ClaudeDir 'agents'
$TargetDir    = Join-Path $SkillsDir 'adversarial-review-gates'
$SyncTargetDir = Join-Path $SkillsDir 'adversarial-review-gates-sync'
$ScriptRoot   = $PSScriptRoot

# Source files
$SrcAgents    = Join-Path $ScriptRoot 'agents'
$SrcSkillMd   = Join-Path $ScriptRoot 'SKILL.md'
$SrcSyncMd    = Join-Path $ScriptRoot 'sync.md'

# ── Pre-checks ───────────────────────────────────────────────────
Write-Host '=== superpowers-adversarial-review installer ===' -ForegroundColor Cyan
Write-Host ''

# Check if superpowers plugin is installed (plugin cache)
$SuperpowersCachePath = Join-Path $ClaudeDir 'plugins\cache\claude-plugins-official\superpowers'
if (Test-Path $SuperpowersCachePath) {
    $Versions = @(Get-ChildItem -Path $SuperpowersCachePath -Directory | Sort-Object Name -Descending)
    if ($Versions.Count -gt 0) {
        Write-Host "[OK] superpowers plugin detected (version: $($Versions[0].Name))" -ForegroundColor Green
    } else {
        Write-Host '[WARN] superpowers directory exists but no version cache found' -ForegroundColor Yellow
    }
} else {
    Write-Host '[WARN] superpowers plugin cache not found, sync will search on first invocation' -ForegroundColor Yellow
}

# ── Backup (if previous install exists) ──────────────────────────
if (Test-Path $TargetDir) {
    $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $BackupDir = Join-Path $ClaudeDir "adversarial-review-gates-backup-$Timestamp"
    Write-Host ''
    Write-Host "Backing up existing install to: $BackupDir" -ForegroundColor Yellow
    Copy-Item -Path $TargetDir -Destination $BackupDir -Recurse -Force
    Write-Host '[OK] Backup complete' -ForegroundColor Green
}

# ── Install main skill ───────────────────────────────────────────
Write-Host ''
Write-Host 'Installing adversarial-review-gates skill...' -ForegroundColor Yellow

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

Copy-Item -Path $SrcSkillMd -Destination (Join-Path $TargetDir 'SKILL.md') -Force
Write-Host '  + adversarial-review-gates/SKILL.md' -ForegroundColor DarkGray

Write-Host '[OK] Main skill installed' -ForegroundColor Green

# ── Install sync skill ───────────────────────────────────────────
Write-Host ''
Write-Host 'Installing adversarial-review-gates-sync skill...' -ForegroundColor Yellow

if (-not (Test-Path $SyncTargetDir)) {
    New-Item -ItemType Directory -Path $SyncTargetDir -Force | Out-Null
}

Copy-Item -Path $SrcSyncMd -Destination (Join-Path $SyncTargetDir 'SKILL.md') -Force
Write-Host '  + adversarial-review-gates-sync/SKILL.md' -ForegroundColor DarkGray

Write-Host '[OK] Sync skill installed' -ForegroundColor Green

# ── Install agents ───────────────────────────────────────────────
Write-Host ''
Write-Host 'Installing agent definitions to ~/.claude/agents/...' -ForegroundColor Yellow

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

Write-Host "[OK] $AgentCount agent definitions installed" -ForegroundColor Green

# ── Summary ──────────────────────────────────────────────────────
Write-Host ''
Write-Host '=== Installation complete ===' -ForegroundColor Cyan
Write-Host ''
Write-Host "  Skills:  $TargetDir" -ForegroundColor White
Write-Host "           $SyncTargetDir" -ForegroundColor White
Write-Host "  Agents:  $AgentsDir ($AgentCount definitions)" -ForegroundColor White
Write-Host ''
Write-Host 'Next step: Run /adversarial-review-gates-sync in Claude Code' -ForegroundColor Yellow
Write-Host '           to inject trigger lines into superpowers skill files.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Uninstall: Remove ~/.claude/skills/adversarial-review-gates{,-sync}/' -ForegroundColor DarkGray
Write-Host '           and the 8 agent files in ~/.claude/agents/' -ForegroundColor DarkGray
