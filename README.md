# superpowers-adversarial-review

将 superpowers 插件的 6 条核心 skill 扩展为多 subagent 对抗验证模式：在需求分析、方案设计、代码实现、调试修复的各个阶段，自动 dispatch 独立上下文的审查 agent 进行交叉验证，利用上下文隔离消除自我确认偏差，以假阳性优先的策略提升产出质量。

## 前置条件

- **Claude Code** 已安装并可正常运行
- **superpowers 插件** 已安装
  - 安装方法见：https://github.com/superpowers-ai/superpowers

## 安装

```powershell
.\install.ps1
```

脚本会自动：
1. 将 `SKILL.md`、`sync.md`、`agents/` 安装到 `~/.claude/skills/adversarial-review-gates/`
2. 清理旧版安装残留（如果有）

安装后在 Claude Code 中调用一次 `/adversarial-review-gates`，触发首次 sync，自动向 superpowers skill 文件注入显式触发行。

## 工作原理

### Sync 注入机制

本项目**不替换** superpowers 的 skill 文件，而是通过 sync 机制向 6 个上游 skill 文件注入最小触发行（用 HTML 注释标记包裹），使 superpowers 工作流在关键节点显式调用 `adversarial-review-gates`。

**注入点：**

| Gate | superpowers skill | 注入位置 |
|------|-------------------|---------|
| 1 | brainstorming | Spec Self-Review 之后、User Review Gate 之前 |
| 2 | writing-plans | Self-Review 之后、Execution Handoff 之前 |
| 3 | subagent-driven-development | Red Flags 之前（新增 Adversarial Review Gate 小节） |
| 3b | executing-plans | 步骤 3（Run verifications）之后 |
| 4 | requesting-code-review | 步骤 2（Dispatch code reviewer）处 |
| 5 | systematic-debugging | Phase 4 Verify Fix 之后 |

**superpowers 更新兼容性：** 更新后触发行丢失，下次调用 `adversarial-review-gates` 时自动检测并重新注入。也可手动调用一次 `/adversarial-review-gates` 恢复。

### 架构概览

```
superpowers 原始流程              对抗验证扩展
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
[subagent-driven-development]     每个 task 完成后 dispatch:
  或                                code-reviewer  (独立审查)
[executing-plans]
  v
[requesting-code-review]          扩展为两批四审:
  |                                 批次1: code-reviewer + security-reviewer
  |                                 批次2: code-verifier + test-reviewer
  v
[systematic-debugging]            修复后 dispatch:
                                    code-reviewer (验证修复)
```

## Agent 简介

| Agent | 模型 | 角色 | 职责 |
|-------|------|------|------|
| requirement-analyzer | sonnet | Producer | 将原始需求转化为结构化需求文档 |
| technical-designer | sonnet | Producer | 基于需求报告产出技术设计方案 |
| plan-reviewer | opus | Critic | 对设计方案进行对抗审查 |
| design-sync | sonnet | Checker | 逐条比对需求与设计的对齐情况 |
| code-reviewer | opus | Critic | 逐文件审查代码变更 |
| code-verifier | sonnet | Checker | 验证代码变更是否完整实现技术设计 |
| security-reviewer | opus | Critic | 安全维度审查（OWASP Top 10） |
| test-reviewer | sonnet | Checker | 评估测试覆盖充分性 |

## 并发约束

所有并行 dispatch 严格限制为每批最多 **2 个** agent：
- writing-plans：`plan-reviewer` + `design-sync` 并行，`technical-designer` 串行
- requesting-code-review：批次 1 并行 2 个，批次 2 并行 2 个，两批串行
- 其他阶段：单个 agent 串行

## 卸载

```powershell
# 1. 删除 skill 目录
Remove-Item -Path "$env:USERPROFILE\.claude\skills\adversarial-review-gates" -Recurse -Force

# 2. 删除 agent 定义
$agents = @('requirement-analyzer','technical-designer','plan-reviewer','design-sync','code-reviewer','code-verifier','security-reviewer','test-reviewer')
foreach ($a in $agents) { Remove-Item "$env:USERPROFILE\.claude\agents\$a.md" -ErrorAction SilentlyContinue }
```

superpowers skill 文件中的注入标记会在下次 superpowers 更新时自动清除。如需立即清除，重新安装 superpowers 插件即可。
