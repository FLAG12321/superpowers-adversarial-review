---
name: adversarial-review-gates
description: >
  Use AFTER any of these superpowers workflow events complete:
  (1) brainstorming writes a spec document,
  (2) writing-plans completes an implementation plan,
  (3) subagent-driven-development or executing-plans completes a task,
  (4) requesting-code-review is about to dispatch reviewers,
  (5) systematic-debugging completes a bug fix.
  Dispatches adversarial review subagents for independent verification.
  Do NOT use this skill if you were dispatched as a subagent.
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

# Adversarial Review Gates

## 自动同步检查

本 skill 被调用时，在执行 Gate 逻辑之前先检查 sync 状态：

1. Glob 搜索 `~/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills/brainstorming/SKILL.md`
2. 对找到的文件 Grep 检查是否包含 `adversarial-review-gates`
3. **未找到** → 读取 `~/.claude/skills/adversarial-review-gates/sync.md`，按其中的注入清单对 6 个 superpowers skill 文件执行注入，完成后继续下方 Gate 逻辑
4. **已找到** → 跳过 sync，直接进入 Gate 逻辑

如果本 skill 被调用时不在任何 superpowers 工作流中（无活跃 Gate），且 sync 刚执行完成，输出 sync 报告后正常结束即可。

在 superpowers 工作流的关键节点，自动 dispatch 独立上下文的审查 agent 进行对抗验证。

**核心原则：上下文隔离。** 同一会话的自我审查因锚定效应无法提供有效验证（Cross-Context Review, Song 2026: 分离上下文 F1=28.6% vs 同会话 24.6%）。所有审查 agent 必须在独立上下文中运行。

**并发约束：每个并行节点最多 2 个 agent。**

## 触发-动作矩阵

根据当前所处的 superpowers 工作流阶段，执行对应的审查动作：

### Gate 1: Spec 验证（brainstorming 完成后）

**触发条件：** brainstorming skill 刚完成 spec 自审，即将进入 User Review Gate。

**动作：** 串行 dispatch `requirement-analyzer` subagent
- 输入：spec 文档路径
- 职责：独立验证需求完整性——功能点是否齐全、约束条件是否明确、验收标准是否可验证、是否存在歧义
- 如果发现遗漏或歧义 → 修复 spec 后再提交用户审查
- 如果通过 → 继续 superpowers 原流程

### Gate 2: Plan 对抗审查（writing-plans 完成后）

**触发条件：** writing-plans skill 刚完成计划自审，即将进入 Execution Handoff。

**动作：** 分两步执行

**步骤 1 — 并行 dispatch（x2）：**
- `plan-reviewer` subagent（Critic 角色，model: opus）
  - 输入：Spec + Plan
  - 职责：逐维度审查（需求覆盖、架构合理性、实施可行性、风险盲区、向后兼容、变更范围）
  - 返回：PASS / CONDITIONAL PASS / FAIL + 缺陷列表
- `design-sync` subagent
  - 输入：Spec + Plan
  - 职责：逐条比对需求与设计的对齐情况（正向覆盖、反向追溯、约束对齐、验收可验证）
  - 返回：追溯矩阵 + 偏差列表

**步骤 2 — 串行 dispatch（步骤 1 通过后）：**
- `technical-designer` subagent
  - 输入：Spec + Plan + 步骤 1 审查报告
  - 职责：以独立视角审视架构决策、模块划分、接口定义是否合理

**处理结果：**
- plan-reviewer 返回 FAIL 或有 HIGH 级缺陷 → 修复后重新审查
- design-sync 发现未覆盖需求或超范围设计 → 修复后重新校验
- technical-designer 发现架构级问题 → 修复后重新走 plan-reviewer
- 全部通过 → 继续 superpowers 原流程进入 Execution Handoff

### Gate 3: Task 审查（代码实现完成后）

**触发条件：** subagent-driven-development 的 task 实现完成，或 executing-plans 完成一个 task。

**动作：** 覆盖 superpowers 的默认审查 agent 选择

当 superpowers 流程指示 dispatch `general-purpose` subagent 进行 task review 时：
- **改用 `code-reviewer` agent type**（独立上下文，Critic 角色，model: opus）
- `code-reviewer` 已内置完整的审查维度（逻辑正确性、边界条件、错误处理、代码风格、性能、安全初筛）
- 其余流程（输入格式、review package、fix 循环）与 superpowers 原流程一致

### Gate 4: 最终代码审查（requesting-code-review 触发时）

**触发条件：** requesting-code-review skill 被调用，准备 dispatch 最终审查。

**动作：** 扩展为两批四审

**批次 1（并行 x2）：**
- `code-reviewer` subagent — 代码质量审查（替代 general-purpose）
- `security-reviewer` subagent — 安全审查（OWASP Top 10、注入、凭据泄露）

**批次 2（批次 1 完成后，并行 x2）：**
- `code-verifier` subagent — 验证代码变更是否完整实现技术设计方案
- `test-reviewer` subagent — 审查测试覆盖（关键路径、边界条件、错误场景、验收标准对齐）

**处理结果：**
- 汇总四个 agent 的报告
- CRITICAL 问题必须修复后重新审查
- IMPORTANT 问题必须修复后继续
- Minor 问题记录，不阻断

### Gate 5: Bug 修复审查（systematic-debugging 完成后）

**触发条件：** systematic-debugging skill 的 Phase 4 完成修复并通过测试验证。

**动作：** 串行 dispatch `code-reviewer` subagent
- 输入：bug 描述 + 修复的代码变更（git diff）
- 职责：独立验证修复未引入新问题
- 对于简单单行修复（如常量修正、typo 修复）可跳过此 gate
- 如果发现修复引入了新的边界条件或逻辑问题 → 反馈给 systematic-debugging 流程

## Agent 定义

agent 定义文件存放在 `~/.claude/agents/` 目录下，通过 Agent 工具的 `subagent_type` 参数按名称调用。

**调用方式：**
```
Agent({
  description: "代码审查",
  subagent_type: "code-reviewer",
  model: "opus",
  prompt: "请审查以下代码变更：\n{diff内容}"
})
```

**可用 agent：**
| subagent_type | 模型 | 用途 |
|---------------|------|------|
| `requirement-analyzer` | sonnet | Gate 1 |
| `plan-reviewer` | opus | Gate 2 步骤 1 |
| `design-sync` | sonnet | Gate 2 步骤 1 |
| `technical-designer` | sonnet | Gate 2 步骤 2 |
| `code-reviewer` | opus | Gate 3/4/5 |
| `security-reviewer` | opus | Gate 4 |
| `code-verifier` | sonnet | Gate 4 |
| `test-reviewer` | sonnet | Gate 4 |

## 全局规则

1. **通过 sync 注入触发行** — 本 skill 通过 sync 机制向 superpowers skill 文件注入显式触发行（HTML 注释标记包裹），确保可靠调用。superpowers 更新后需重新同步（调用 `adversarial-gates-sync` skill 或等待下次本 skill 被调用时自动同步）
2. **审查 agent 使用独立上下文** — 不传递主 agent 的推理历史，只传递 Spec/Plan/Diff 等产出物
3. **Critic 角色偏向假阳性** — 宁可误报不可漏报
4. **模型分离** — Critic 角色（plan-reviewer, code-reviewer, security-reviewer）用 opus 优化推理，其他用 sonnet 控制成本
5. **审查报告格式化** — 所有审查 agent 有自己的输出格式定义，直接使用其返回结果
6. **中文输出** — 所有审查报告使用中文
7. **使用 subagent_type 调用** — 所有 agent 通过 Agent 工具的 `subagent_type` 参数按名称调用，model 参数显式指定

## 如何判断当前处于哪个 Gate

- 如果刚完成 spec 文档写入和自审 → Gate 1
- 如果刚完成 plan 文档写入和自审 → Gate 2
- 如果刚完成一个 task 的实现 → Gate 3
- 如果 requesting-code-review skill 被调用 → Gate 4
- 如果 systematic-debugging 完成了 Phase 4 修复 → Gate 5
- 如果不确定 → 根据最近的 superpowers skill 调用记录判断
