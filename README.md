# superpowers-adversarial-review

Extends 6 core superpowers skills with multi-subagent adversarial verification: at each stage of requirements analysis, design, implementation, and debugging, automatically dispatches review agents in isolated contexts for cross-verification, leveraging context isolation to eliminate self-confirmation bias with a false-positive-first strategy.

## Prerequisites

- **Claude Code** installed and working
- **superpowers plugin** installed
  - Install: https://github.com/superpowers-ai/superpowers

## Installation

```powershell
.\install.ps1
```

The script will:
1. Install `SKILL.md` to `~/.claude/skills/adversarial-review-gates/`
2. Install `sync.md` as `SKILL.md` to `~/.claude/skills/adversarial-review-gates-sync/`
3. Install agent definitions to `~/.claude/agents/`
4. Back up any existing installation

After installation, run `/adversarial-review-gates-sync` in Claude Code to inject trigger lines into superpowers skill files.

## How It Works

### Two Skills

| Skill | Command | Purpose |
|-------|---------|---------|
| adversarial-review-gates | `/adversarial-review-gates` | Gate logic — dispatches review agents at workflow checkpoints |
| adversarial-review-gates-sync | `/adversarial-review-gates-sync` | Injects trigger lines into superpowers skill files |

Run sync once after install and again after each superpowers upgrade. The sync injects `<EXTREMELY-IMPORTANT>` blocks into 7 superpowers skill files to ensure gates are reliably triggered.

### Sync Injection Mechanism

This project **does not replace** superpowers skill files. Instead, sync injects minimal trigger lines (wrapped in HTML comment markers) into 7 upstream skill files, causing superpowers workflows to explicitly invoke `adversarial-review-gates` at critical checkpoints.

**Injection points:**

| Gate | superpowers skill | Injection location |
|------|-------------------|-------------------|
| 0 | using-superpowers | Before Skill Priority (global fallback rule) |
| 1 | brainstorming | After Spec Self-Review, before User Review Gate |
| 2 | writing-plans | After Self-Review, before Execution Handoff |
| 3 | subagent-driven-development | Before Red Flags (new Adversarial Review Gate section) |
| 3b | executing-plans | After step 3 (Run verifications) |
| 4 | requesting-code-review | At step 2 (Dispatch code reviewer) |
| 5 | systematic-debugging | After Phase 4 Verify Fix |

**superpowers upgrade compatibility:** After upgrading, trigger lines are lost. Run `/adversarial-review-gates-sync` to re-inject.

### Architecture Overview

```
superpowers original flow              adversarial verification extension
========================              ====================================

[brainstorming]                       after spec written, dispatch:
  |  write spec                         requirement-analyzer (independent verification)
  v
[writing-plans]                       after self-review, parallel dispatch (x2):
  |  write plan                         plan-reviewer  (Critic, find defects)
  |                                     design-sync    (consistency check)
  |                                   after both pass, serial dispatch:
  |                                     technical-designer (technical verification)
  v
[subagent-driven-development]         after each task completes, dispatch:
  or                                    code-reviewer  (independent review)
[executing-plans]
  v
[requesting-code-review]              expand to two-batch, four-reviewer:
  |                                     batch 1: code-reviewer + security-reviewer
  |                                     batch 2: code-verifier + test-reviewer
  v
[systematic-debugging]                after fix, dispatch:
                                        code-reviewer (verify fix)
```

## Agents

| Agent | Model | Role | Responsibility |
|-------|-------|------|----------------|
| requirement-analyzer | sonnet | Producer | Transform raw requirements into structured requirement document |
| technical-designer | sonnet | Producer | Produce technical design based on requirement report |
| plan-reviewer | opus | Critic | Adversarial review of design plans |
| design-sync | sonnet | Checker | Item-by-item comparison of requirement-design alignment |
| code-reviewer | opus | Critic | File-by-file code change review |
| code-verifier | sonnet | Checker | Verify code changes completely implement technical design |
| security-reviewer | opus | Critic | Security review (OWASP Top 10) |
| test-reviewer | sonnet | Checker | Evaluate test coverage adequacy |

## Concurrency Constraints

All parallel dispatches are strictly limited to **2 agents** per batch:
- writing-plans: `plan-reviewer` + `design-sync` parallel, `technical-designer` serial
- requesting-code-review: batch 1 parallel (2), batch 2 parallel (2), batches serial
- Other stages: single agent serial

## Uninstall

```powershell
# 1. Remove skill directories
Remove-Item -Path "$env:USERPROFILE\.claude\skills\adversarial-review-gates" -Recurse -Force
Remove-Item -Path "$env:USERPROFILE\.claude\skills\adversarial-review-gates-sync" -Recurse -Force

# 2. Remove agent definitions
$agents = @('requirement-analyzer','technical-designer','plan-reviewer','design-sync','code-reviewer','code-verifier','security-reviewer','test-reviewer')
foreach ($a in $agents) { Remove-Item "$env:USERPROFILE\.claude\agents\$a.md" -ErrorAction SilentlyContinue }
```

Trigger lines in superpowers skill files are automatically cleared on next superpowers update. To clear immediately, reinstall the superpowers plugin.
