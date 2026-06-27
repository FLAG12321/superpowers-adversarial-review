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

At critical checkpoints in superpowers workflows, automatically dispatch review agents in isolated contexts for adversarial verification.

**Prerequisites:** Run `/adversarial-review-gates-sync` once after first install or after superpowers upgrades to inject trigger lines into superpowers skill files.

**Core principle: Context isolation.** Self-review within the same session cannot provide effective verification due to anchoring bias (Cross-Context Review, Song 2026: separated context F1=28.6% vs same-session 24.6%). All review agents MUST run in isolated contexts.

**Concurrency constraint: Maximum 2 agents per parallel node.**

## Trigger-Action Matrix

Execute the corresponding review action based on the current superpowers workflow stage:

### Gate 1: Spec Verification (after brainstorming completes)

**Trigger:** brainstorming skill has just completed spec self-review, about to enter User Review Gate.

**Action:** Serial dispatch of `requirement-analyzer` subagent
- Input: spec document path
- Responsibilities: Independent verification of requirement completeness — are all features covered, are constraints explicit, are acceptance criteria verifiable, are there ambiguities
- If gaps or ambiguities found → fix spec before submitting for user review
- If passed → continue superpowers original flow

### Gate 2: Adversarial Plan Review (after writing-plans completes)

**Trigger:** writing-plans skill has just completed plan self-review, about to enter Execution Handoff.

**Action:** Execute in two steps

**Step 1 — Parallel dispatch (x2):**
- `plan-reviewer` subagent (Critic role, model: opus)
  - Input: Spec + Plan
  - Responsibilities: Dimension-by-dimension review (requirement coverage, architecture soundness, implementation feasibility, risk blind spots, backward compatibility, change scope)
  - Returns: PASS / CONDITIONAL PASS / FAIL + defect list
- `design-sync` subagent
  - Input: Spec + Plan
  - Responsibilities: Item-by-item comparison of requirement-design alignment (forward coverage, reverse traceability, constraint alignment, acceptance verifiability)
  - Returns: traceability matrix + deviation list

**Step 2 — Serial dispatch (after step 1 passes):**
- `technical-designer` subagent
  - Input: Spec + Plan + Step 1 review reports
  - Responsibilities: Independent perspective on architecture decisions, module decomposition, interface definitions

**Result handling:**
- plan-reviewer returns FAIL or has HIGH-severity defects → fix and re-review
- design-sync finds uncovered requirements or out-of-scope design → fix and re-verify
- technical-designer finds architecture-level issues → fix and re-run plan-reviewer
- All pass → continue superpowers original flow into Execution Handoff

### Gate 3: Task Review (after code implementation completes)

**Trigger:** subagent-driven-development task implementation completes, or executing-plans completes a task.

**Action:** Override superpowers' default review agent selection

When superpowers flow instructs dispatching a `general-purpose` subagent for task review:
- **Use `code-reviewer` agent type instead** (isolated context, Critic role, model: opus)
- `code-reviewer` has built-in comprehensive review dimensions (logical correctness, boundary conditions, error handling, code style, performance, security screening)
- Remaining flow (input format, review package, fix loop) stays consistent with superpowers original flow

### Gate 4: Final Code Review (when requesting-code-review triggers)

**Trigger:** requesting-code-review skill is invoked, preparing to dispatch final review.

**Action:** Expand to two-batch, four-reviewer dispatch

**Batch 1 (parallel x2):**
- `code-reviewer` subagent — code quality review (replaces general-purpose)
- `security-reviewer` subagent — security review (OWASP Top 10, injection, credential leaks)

**Batch 2 (after batch 1 completes, parallel x2):**
- `code-verifier` subagent — verify code changes completely implement the technical design
- `test-reviewer` subagent — review test coverage (critical paths, boundary conditions, error scenarios, acceptance criteria alignment)

**Result handling:**
- Aggregate all four agents' reports
- CRITICAL issues must be fixed and re-reviewed
- IMPORTANT issues must be fixed before continuing
- Minor issues are recorded, non-blocking

### Gate 5: Bug Fix Review (after systematic-debugging completes)

**Trigger:** systematic-debugging skill Phase 4 completes fix and passes test verification.

**Action:** Serial dispatch of `code-reviewer` subagent
- Input: bug description + fix code changes (git diff)
- Responsibilities: Independently verify the fix does not introduce new issues
- May skip this gate for trivial single-line fixes (constant corrections, typo fixes)
- If the fix introduces new boundary conditions or logic issues → feed back to systematic-debugging flow

## Agent Definitions

Agent definition files are stored in `~/.claude/agents/` directory, invoked by name via the Agent tool's `subagent_type` parameter.

**Invocation:**
```
Agent({
  description: "Code review",
  subagent_type: "code-reviewer",
  model: "opus",
  prompt: "Please review the following code changes:\n{diff content}"
})
```

**Available agents:**
| subagent_type | Model | Purpose |
|---------------|-------|---------|
| `requirement-analyzer` | sonnet | Gate 1 |
| `plan-reviewer` | opus | Gate 2 Step 1 |
| `design-sync` | sonnet | Gate 2 Step 1 |
| `technical-designer` | sonnet | Gate 2 Step 2 |
| `code-reviewer` | opus | Gate 3/4/5 |
| `security-reviewer` | opus | Gate 4 |
| `code-verifier` | sonnet | Gate 4 |
| `test-reviewer` | sonnet | Gate 4 |

## Global Rules

1. **Trigger lines injected via sync** — Run `/adversarial-review-gates-sync` to inject trigger lines into superpowers skill files. Re-run after superpowers updates.
2. **Review agents use isolated contexts** — Do not pass the main agent's reasoning history, only pass artifacts (Spec/Plan/Diff etc.)
3. **Critic roles bias toward false positives** — Better to over-report than to miss issues
4. **Model separation** — Critic roles (plan-reviewer, code-reviewer, security-reviewer) use opus for optimized reasoning, others use sonnet for cost control
5. **Review report formatting** — All review agents have their own output format definitions, use their returned results directly
6. **Use subagent_type for invocation** — All agents are invoked via the Agent tool's `subagent_type` parameter by name, with model parameter explicitly specified

## How to Determine the Current Gate

- If spec document was just written and self-reviewed → Gate 1
- If plan document was just written and self-reviewed → Gate 2
- If a task implementation was just completed → Gate 3
- If requesting-code-review skill was invoked → Gate 4
- If systematic-debugging completed Phase 4 fix → Gate 5
- If uncertain → determine based on the most recent superpowers skill invocation record
