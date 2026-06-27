# superpowers-adversarial-review

将 superpowers 插件的 6 条核心 skill 扩展为多 subagent 对抗验证模式：在需求分析、方案设计、代码实现、调试修复的各个阶段，自动 dispatch 独立上下文的审查 agent 进行交叉验证，利用上下文隔离消除自我确认偏差，以假阳性优先的策略提升产出质量。

## 前置条件

- **Claude Code** 已安装并可正常运行
- **superpowers 插件** 已安装（`~/.claude/skills/using-superpowers/SKILL.md` 存在）
  - 安装方法见：https://github.com/superpowers-ai/superpowers
- **PowerShell 5.1+**（Windows 10 自带）

## 安装

```powershell
# 在项目根目录运行
.\install.ps1
```

脚本会自动：
1. 检查 superpowers 是否已安装
2. 备份即将被覆盖的 skill 文件到 `~/.claude/skills-backup-{时间戳}/`
3. 复制 8 个 agent 定义到 `~/.claude/agents/`
4. 覆盖 7 个 skill patch 到 `~/.claude/skills/` 对应位置

## 架构概览

```
superpowers 原始流程              对抗验证扩展（本项目新增）
========================          ============================

[brainstorming]                   写完 spec 后 dispatch:
  |  写 spec                        requirement-analyzer (独立验证)
  v
[writing-plans]                   自审完成后并行 dispatch (x2):
  |  写 plan                        plan-reviewer  (Critic, 找缺陷)
  |                                 design-sync    (一致性校验)
  |                               两者通过后串行 dispatch:
  |                                 technical-designer (技术验证)
  v
[subagent-driven-development]     每个 task 完成后分两批 dispatch:
  或                                批次1 (并行x2):
[executing-plans]                     code-reviewer  (代码审查)
  |  执行 task                        security-reviewer (安全审查)
  |                                 批次2 (并行x2):
  |                                   code-verifier  (设计合规)
  |                                   test-reviewer  (测试覆盖)
  v
[requesting-code-review]          同上两批四审架构
  |
  v
[systematic-debugging]            修复后 dispatch:
  |                                 code-reviewer (验证修复)
  v
[finishing-a-development-branch]  (未修改)
```

## Agent 简介

| Agent | 模型 | 角色 | 职责 |
|-------|------|------|------|
| requirement-analyzer | sonnet | Producer | 将原始需求转化为结构化需求文档（功能点、约束、验收标准） |
| technical-designer | sonnet | Producer | 基于需求报告产出技术设计方案（架构决策、模块设计、实施步骤） |
| plan-reviewer | opus | Critic | 对设计方案进行对抗审查，逐维度评估（需求覆盖、架构合理性、风险盲区等） |
| design-sync | sonnet | Checker | 逐条比对需求与设计的对齐情况，输出追溯矩阵 |
| code-reviewer | opus | Critic | 逐文件审查代码变更（逻辑正确性、边界条件、错误处理、性能、安全初筛） |
| code-verifier | sonnet | Checker | 验证代码变更是否完整实现了技术设计方案的每个步骤 |
| security-reviewer | opus | Critic | 专注安全维度审查（OWASP Top 10、注入、凭据泄露、数据安全） |
| test-reviewer | sonnet | Checker | 评估测试覆盖充分性（关键路径、边界条件、错误场景、验收标准对齐） |

## Skill Patch 改动说明

| Skill | 修改的文件 | 改动内容 |
|-------|-----------|---------|
| brainstorming | SKILL.md | 写完 spec 后新增 "Adversarial Requirements Verification" 步骤：dispatch `requirement-analyzer` subagent 对 spec 进行独立验证 |
| writing-plans | SKILL.md | 自审后新增 "Adversarial Plan Review" 步骤：并行 dispatch `plan-reviewer` + `design-sync`，通过后串行 dispatch `technical-designer` 技术验证 |
| requesting-code-review | SKILL.md | 扩展为两批四审：批次1 并行 `code-reviewer` + `security-reviewer`，批次2 并行 `code-verifier` + `test-reviewer` |
| requesting-code-review | code-reviewer.md | 代码审查 prompt 模板（未修改原始模板，但被扩展流程引用） |
| subagent-driven-development | task-reviewer-prompt.md | Task 级审查 prompt 模板，供 subagent-driven-development 的 task 完成后调用 |
| executing-plans | SKILL.md | 每个 task 执行后 dispatch `code-reviewer` subagent 独立审查变更 |
| systematic-debugging | SKILL.md | Phase 4（修复实现）增加 dispatch `code-reviewer` 审查修复变更的步骤 |

## 并发约束

Claude API 的 subagent 并发数限制为 **2**。本项目的所有并行 dispatch 都严格遵守此限制：

- **writing-plans 阶段**：`plan-reviewer` + `design-sync` 并行（2 个），`technical-designer` 串行
- **code review 阶段**：
  - 批次 1：`code-reviewer` + `security-reviewer` 并行（2 个）
  - 批次 2：`code-verifier` + `test-reviewer` 并行（2 个）
  - 两批串行执行，每批内并行不超过 2
- **其他阶段**：单个 subagent 串行 dispatch

不要手动修改 skill 文件中的并行数量，否则可能触发 API 限流或排队等待。

## 卸载

```powershell
# 1. 从备份恢复 skill 文件（替换安装时间戳）
$backup = "$env:USERPROFILE\.claude\skills-backup-YYYYMMDD-HHmmss"
Copy-Item -Path "$backup\*" -Destination "$env:USERPROFILE\.claude\skills\" -Recurse -Force

# 2. 删除 agent 定义文件
$agents = @(
    'requirement-analyzer.md',
    'technical-designer.md',
    'plan-reviewer.md',
    'design-sync.md',
    'code-reviewer.md',
    'code-verifier.md',
    'security-reviewer.md',
    'test-reviewer.md'
)
foreach ($a in $agents) {
    $path = Join-Path "$env:USERPROFILE\.claude\agents" $a
    if (Test-Path $path) { Remove-Item $path }
}

# 3. 删除备份目录（确认不再需要后）
Remove-Item -Path $backup -Recurse -Force
```

如果没有备份（首次安装时目标文件不存在的情况），直接重新安装 superpowers 即可恢复原始 skill 文件。
