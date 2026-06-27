---
name: adversarial-gates-sync
description: >
  Run once after first install, or after superpowers upgrades.
  Injects hard-constraint trigger lines into superpowers skill files so adversarial-review-gates is reliably invoked.
---

# Adversarial Gates Sync

Inject hard-constraint trigger lines into 7 superpowers skill files, ensuring superpowers workflows **MUST** invoke `adversarial-review-gates` at critical checkpoints.

**Design principles:**
- All injected content is wrapped in `<EXTREMELY-IMPORTANT>` blocks, matching superpowers' native highest-priority semantic tag
- Injected content is wrapped in HTML comment markers for detection/update/cleanup
- Paths are discovered dynamically via Glob, compatible with superpowers version upgrades
- Each injection only adds trigger lines — no other superpowers content is modified

## Execution Steps

### Step 1: Discover superpowers cache path

Use Glob to search:
```
~/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills/brainstorming/SKILL.md
```

Extract the base path from the result. For example, if the result is `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.0.3/skills/brainstorming/SKILL.md`, the base path is `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.0.3/skills/`.

If multiple version directories exist, use the one with the highest version number.

If no results found → report "superpowers plugin cache not found" and stop.

### Step 2: Check and inject each file

For each of the 7 injection targets below:

1. Grep for the `adversarial-review-gates:gate-N` marker
2. If marker exists → **check if it is the old format** (does not contain `EXTREMELY-IMPORTANT`)
   - Old format → delete the old marker interval (from `<!-- adversarial-review-gates:gate-N:start -->` to `<!-- adversarial-review-gates:gate-N:end -->` inclusive), then inject the new version
   - New format → mark as OK, skip
3. If marker does not exist → read the file, locate the anchor, inject using the Edit tool

**Old format detection:** If the marker interval does **not** contain the string `EXTREMELY-IMPORTANT`, it is old format.

If the anchor text does not exist in the file (superpowers restructured that section):
- Read the full file, understand the new paragraph structure
- Find a semantically equivalent position (after self-review completes → before user review, after verification → before next step, etc.)
- Inject at the new position
- If no semantically equivalent position can be found → mark as MANUAL, record in report

---

## Injection Manifest

### Gate 0: using-superpowers/SKILL.md (global fallback)

**File:** `{base_path}/using-superpowers/SKILL.md`

**Anchor:** Before the `## Skill Priority` line (note: insert BEFORE the anchor, not after)

**Injection content:**
```markdown
<!-- adversarial-review-gates:gate-0:start -->
<EXTREMELY-IMPORTANT>
## Adversarial Review Gates — Mandatory Global Rule

After the following superpowers skills produce their key artifacts, you **MUST** invoke the `adversarial-review-gates` skill for independent adversarial review. This is NOT optional — skipping it means skipping a quality gate.

| Completed Skill | Artifact | Required Gate |
|----------------|----------|---------------|
| brainstorming | spec written + self-review passed | Gate 1: Spec Verification |
| writing-plans | plan written + self-review passed | Gate 2: Adversarial Plan Review |
| subagent-driven-development | single task implementation done | Gate 3: Task Review |
| executing-plans | single task verification passed | Gate 3: Task Review |
| requesting-code-review | skill invoked | Gate 4: Final Code Review |
| systematic-debugging | Phase 4 fix passes tests | Gate 5: Bug Fix Review |

**If you do not see an explicit instruction to call adversarial-review-gates within any of the above skills' flows, it may have been omitted — but this global rule still applies. You MUST proactively invoke it.**
</EXTREMELY-IMPORTANT>

<!-- adversarial-review-gates:gate-0:end -->

```

---

### Gate 1: brainstorming/SKILL.md

**File:** `{base_path}/brainstorming/SKILL.md`

**Anchor:** After the line containing `Fix any issues inline. No need to re-review`

**Injection content:**
```markdown

<!-- adversarial-review-gates:gate-1:start -->
<EXTREMELY-IMPORTANT>
**Adversarial Spec Review — MANDATORY:**
After self-review passes, you **MUST** invoke the `adversarial-review-gates` skill (Gate 1: Spec Verification) for independent requirement verification **BEFORE** proceeding to the User Review Gate.

Skipping this step is a workflow violation — even if the spec looks perfect, independent review can still uncover blind spots. If you find yourself wanting to skip this, that is exactly the rationalization behavior described in the Red Flags table.
</EXTREMELY-IMPORTANT>
<!-- adversarial-review-gates:gate-1:end -->
```

---

### Gate 2: writing-plans/SKILL.md

**File:** `{base_path}/writing-plans/SKILL.md`

**Anchor:** After the line containing `If you find a spec requirement with no task, add the task.`

**Injection content:**
```markdown

<!-- adversarial-review-gates:gate-2:start -->
<EXTREMELY-IMPORTANT>
**Adversarial Plan Review — MANDATORY:**
After plan self-review passes, you **MUST** invoke the `adversarial-review-gates` skill (Gate 2: Adversarial Plan Review) for independent plan verification **BEFORE** proceeding to the Execution Handoff.

Skipping this step is a workflow violation — architectural flaws in the plan are extremely costly to fix after implementation. If you find yourself wanting to skip this, that is exactly the rationalization behavior described in the Red Flags table.
</EXTREMELY-IMPORTANT>
<!-- adversarial-review-gates:gate-2:end -->
```

---

### Gate 3a: subagent-driven-development/SKILL.md

**File:** `{base_path}/subagent-driven-development/SKILL.md`

**Anchor:** Before the `## Red Flags` line (note: insert BEFORE the anchor, not after)

**Injection content:**
```markdown
<!-- adversarial-review-gates:gate-3:start -->
<EXTREMELY-IMPORTANT>
## Adversarial Review Gate — MANDATORY

After each task's code quality review passes and the task is marked complete, you **MUST** invoke the `adversarial-review-gates` skill (Gate 3: Task Review) for independent adversarial review. The skill uses an opus-powered `code-reviewer` in isolated context, providing a third review layer beyond spec compliance and code quality.

Skipping this step is a workflow violation.
</EXTREMELY-IMPORTANT>
<!-- adversarial-review-gates:gate-3:end -->

```

---

### Gate 3b: executing-plans/SKILL.md

**File:** `{base_path}/executing-plans/SKILL.md`

**Anchor:** After the line containing `3. Run verifications as specified`

**Injection content:**
```markdown
<!-- adversarial-review-gates:gate-3b:start -->
<EXTREMELY-IMPORTANT>
   - **MANDATORY:** After verifications pass, you **MUST** invoke the `adversarial-review-gates` skill (Gate 3: Task Review) for independent code review **BEFORE** marking the task as completed. Skipping this step is a workflow violation.
</EXTREMELY-IMPORTANT>
<!-- adversarial-review-gates:gate-3b:end -->
```

---

### Gate 4: requesting-code-review/SKILL.md

**File:** `{base_path}/requesting-code-review/SKILL.md`

**Anchor:** After the line containing `Dispatch a \`general-purpose\` subagent` (the step 2 dispatcher instruction)

**Injection content:**
```markdown

<!-- adversarial-review-gates:gate-4:start -->
<EXTREMELY-IMPORTANT>
**MANDATORY:** Do NOT use the default single-reviewer dispatch above. You **MUST** invoke the `adversarial-review-gates` skill (Gate 4: Final Code Review). The skill replaces the default flow with two-batch, four-reviewer dispatch (batch 1: code + security, batch 2: verification + test review).

Skipping this step and using the default dispatch is a workflow violation.
</EXTREMELY-IMPORTANT>
<!-- adversarial-review-gates:gate-4:end -->
```

---

### Gate 5: systematic-debugging/SKILL.md

**File:** `{base_path}/systematic-debugging/SKILL.md`

**Anchor:** After the line containing `Issue actually resolved?`

**Injection content:**
```markdown

<!-- adversarial-review-gates:gate-5:start -->
<EXTREMELY-IMPORTANT>
4. **Adversarial Fix Review (MANDATORY for non-trivial fixes):**
   You **MUST** invoke the `adversarial-review-gates` skill (Gate 5: Bug Fix Review) to independently verify the fix does not introduce new issues. May only be skipped for trivial single-line fixes (typos, constant corrections).

   If you are unsure whether the fix is "trivial" — it is not trivial. You MUST run the review.
</EXTREMELY-IMPORTANT>
<!-- adversarial-review-gates:gate-5:end -->
```

---

## Step 3: Output report

After all injections are complete, output the following report:

```markdown
# Adversarial Gates Sync Report

**superpowers version:** {version}
**cache path:** {base_path}
**constraint level:** EXTREMELY-IMPORTANT (hard constraint)

| Gate | File | Status | Notes |
|------|------|--------|-------|
| 0 | using-superpowers/SKILL.md | OK / INJECTED / UPGRADED / MANUAL | ... |
| 1 | brainstorming/SKILL.md | OK / INJECTED / UPGRADED / MANUAL | ... |
| 2 | writing-plans/SKILL.md | OK / INJECTED / UPGRADED / MANUAL | ... |
| 3a | subagent-driven-development/SKILL.md | OK / INJECTED / UPGRADED / MANUAL | ... |
| 3b | executing-plans/SKILL.md | OK / INJECTED / UPGRADED / MANUAL | ... |
| 4 | requesting-code-review/SKILL.md | OK / INJECTED / UPGRADED / MANUAL | ... |
| 5 | systematic-debugging/SKILL.md | OK / INJECTED / UPGRADED / MANUAL | ... |

## Manual action required
- [Write "None" if none]
```

Status meanings:
- **OK** — New-format hard-constraint marker already exists, no action needed
- **INJECTED** — First-time injection
- **UPGRADED** — Old weak-constraint marker cleaned up, new hard-constraint injected
- **MANUAL** — Anchor not found, requires manual intervention

## Rules

- Only add trigger lines — do not modify any other superpowers file content
- All injected content must be wrapped in `<!-- adversarial-review-gates:gate-N:start/end -->` markers
- All injected content must contain an `<EXTREMELY-IMPORTANT>` block
- Do not re-inject if new-format marker already exists
- Old-format markers must be cleaned up before injecting the new version
