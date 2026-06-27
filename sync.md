---
name: adversarial-gates-sync
description: >
  首次安装后运行一次，或 superpowers 升级后运行。
  向 superpowers skill 文件注入显式触发行，使 adversarial-review-gates 被可靠调用。
---

# Adversarial Gates Sync

向 superpowers 的 6 个 skill 文件注入显式触发行，让 superpowers 工作流在关键节点自动调用 `adversarial-review-gates`。

**设计原则：**
- 注入内容用 HTML 注释标记包裹，支持检测/更新/清理
- 路径通过 Glob 动态发现，兼容 superpowers 版本升级
- 每次注入仅添加触发行，不改动 superpowers 的其他内容

## 执行步骤

### 步骤 1：发现 superpowers 缓存路径

使用 Glob 工具搜索：
```
~/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills/brainstorming/SKILL.md
```

从结果中提取基路径。例如结果为 `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/skills/brainstorming/SKILL.md`，则基路径为 `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/skills/`。

如果存在多个版本目录，取版本号最大的那个。

如果未找到任何结果 → 报告"未找到 superpowers 插件缓存"，终止。

### 步骤 2：逐文件检查与注入

对以下 6 个注入目标，依次执行：

1. Grep 搜索 `adversarial-review-gates:gate-N` 标记
2. 已存在 → 标记 OK，跳过
3. 不存在 → 读取文件，定位锚点，使用 Edit 工具注入

如果锚点文本在文件中不存在（superpowers 重构了该段落）：
- 读取文件全文，理解新的段落结构
- 找语义等价的位置（自审完成 → 用户审查之间、验证完成 → 下一步之前等）
- 在新位置注入
- 如果找不到语义等价位置 → 标记 MANUAL，记录到报告

---

## 注入清单

### Gate 1: brainstorming/SKILL.md

**文件：** `{基路径}/brainstorming/SKILL.md`

**锚点：** 在包含 `Fix any issues inline. No need to re-review` 的行之后

**注入内容：**
```markdown

<!-- adversarial-review-gates:gate-1:start -->
**Adversarial Spec Review:**
After self-review passes, invoke `adversarial-review-gates` skill (Gate 1: Spec 验证) for independent requirement verification before proceeding to User Review Gate.
<!-- adversarial-review-gates:gate-1:end -->
```

---

### Gate 2: writing-plans/SKILL.md

**文件：** `{基路径}/writing-plans/SKILL.md`

**锚点：** 在包含 `If you find a spec requirement with no task, add the task.` 的行之后

**注入内容：**
```markdown

<!-- adversarial-review-gates:gate-2:start -->
**Adversarial Plan Review:**
After self-review passes, invoke `adversarial-review-gates` skill (Gate 2: Plan 对抗审查) for independent plan verification before proceeding to Execution Handoff.
<!-- adversarial-review-gates:gate-2:end -->
```

---

### Gate 3a: subagent-driven-development/SKILL.md

**文件：** `{基路径}/subagent-driven-development/SKILL.md`

**锚点：** 在 `## Red Flags` 行之前（注意：这里是插入在锚点之前，不是之后）

**注入内容：**
```markdown
<!-- adversarial-review-gates:gate-3:start -->
## Adversarial Review Gate

After each task's code quality review passes and the task is marked complete, invoke `adversarial-review-gates` skill (Gate 3: Task 审查) for independent adversarial review. The skill uses opus-powered `code-reviewer` in isolated context, adding a third review stage beyond spec compliance and code quality.
<!-- adversarial-review-gates:gate-3:end -->

```

---

### Gate 3b: executing-plans/SKILL.md

**文件：** `{基路径}/executing-plans/SKILL.md`

**锚点：** 在包含 `3. Run verifications as specified` 的行之后

**注入内容：**
```markdown
<!-- adversarial-review-gates:gate-3b:start -->
   - **REQUIRED:** After verifications pass, invoke `adversarial-review-gates` skill (Gate 3: Task 审查) for independent code review
<!-- adversarial-review-gates:gate-3b:end -->
```

---

### Gate 4: requesting-code-review/SKILL.md

**文件：** `{基路径}/requesting-code-review/SKILL.md`

**锚点：** 在包含 `Dispatch a \`general-purpose\` subagent` 的行之后（即步骤 2 的 dispatcher 说明处）

**注入内容：**
```markdown

<!-- adversarial-review-gates:gate-4:start -->
**REQUIRED:** Instead of the default single-reviewer dispatch above, invoke `adversarial-review-gates` skill (Gate 4: 最终代码审查). The skill handles multi-agent review in two batches (code + security, then verification + test review).
<!-- adversarial-review-gates:gate-4:end -->
```

---

### Gate 5: systematic-debugging/SKILL.md

**文件：** `{基路径}/systematic-debugging/SKILL.md`

**锚点：** 在包含 `Issue actually resolved?` 的行之后

**注入内容：**
```markdown

<!-- adversarial-review-gates:gate-5:start -->
4. **Adversarial Fix Review (non-trivial fixes only)**
   Invoke `adversarial-review-gates` skill (Gate 5: Bug 修复审查) to independently verify the fix doesn't introduce new issues. Skip for trivial single-line fixes (typos, constant corrections).
<!-- adversarial-review-gates:gate-5:end -->
```

---

## 步骤 3：输出报告

完成所有注入后，输出以下格式的报告：

```markdown
# Adversarial Gates Sync Report

**superpowers 版本：** {版本号}
**缓存路径：** {基路径}

| Gate | 文件 | 状态 | 说明 |
|------|------|------|------|
| 1 | brainstorming/SKILL.md | OK / INJECTED / MANUAL | ... |
| 2 | writing-plans/SKILL.md | OK / INJECTED / MANUAL | ... |
| 3a | subagent-driven-development/SKILL.md | OK / INJECTED / MANUAL | ... |
| 3b | executing-plans/SKILL.md | OK / INJECTED / MANUAL | ... |
| 4 | requesting-code-review/SKILL.md | OK / INJECTED / MANUAL | ... |
| 5 | systematic-debugging/SKILL.md | OK / INJECTED / MANUAL | ... |

## 需要人工处理
- [如无则写"无"]
```

## 行为准则

- 仅添加触发行，不修改 superpowers 文件的其他内容
- 所有注入内容必须用 `<!-- adversarial-review-gates:gate-N:start/end -->` 标记包裹
- 标记已存在时不重复注入
- 中文输出
