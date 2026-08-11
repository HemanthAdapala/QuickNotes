---
name: the-honoured-one
description: "Forces the AI to fully load context and read relevant files before performing complex, multi-file tasks, architectural changes, or debugging. Prevents acting on assumptions."
risk: safe
source: community
date_added: "2026-06-25"
---

# the-honoured-one — Full Context Load Protocol

## Overview

> Gojo at full power means all six eyes open — everything visible, nothing assumed, no blind spots. The Honoured One doesn't act on guesses. This skill enforces the same: the AI must earn the right to act by reading and understanding first.

The most common AI coding failure is **confident wrongness** — the AI proposes or implements something based on how it assumes the code is structured, not how it actually is. It gets the architecture wrong, uses a pattern inconsistent with the rest of the codebase, or integrates with a module it never actually opened. This skill eliminates that failure mode by making context-loading mandatory before any action.

---

## When to Use This Skill

- Use when modifying multiple files in an existing codebase
- Use when designing or modifying a system component
- Use when adding a feature that integrates with existing code
- Use when debugging a system or component the AI has not yet read
- Use when the AI would need to assume how existing code is structured
- **DO NOT** use for isolated single-file tasks where the file has already been read

---

## How It Works

### PHASE 1 — Context Audit

When given any complex task, the AI must immediately perform a context audit before proposing anything. It declares:

1. **What files are relevant to this task?** — Every file that will be read, changed, or is upstream/downstream of the change
2. **Which of those has the AI actually read this session?** — Honest accounting, no assumptions
3. **What gaps exist?** — Files that are relevant but unread

The AI outputs this before doing anything else:

```
THE HONOURED ONE — CONTEXT AUDIT
─────────────────────────────────────────
Task: [what was asked]

Relevant files identified:
  - src/auth/middleware.ts       → [why relevant]
  - src/routes/user.ts          → [why relevant]
  - src/models/user.model.ts    → [why relevant]
  - src/utils/token.ts          → [why relevant]

Files read this session:
  - src/routes/user.ts          → ✓ read

Unread but relevant (blind spots):
  - src/auth/middleware.ts       → ✗ not read
  - src/models/user.model.ts    → ✗ not read
  - src/utils/token.ts          → ✗ not read
─────────────────────────────────────────
Cannot proceed — reading blind spots now.
```

> **The AI cannot propose a solution, make a plan, or write any code while blind spots exist.**

---

### PHASE 2 — Mandatory Read Pass

The AI reads every file listed as a blind spot. Not summaries, not assumptions based on filename or folder structure — actual reads.

Rules for this phase:
- If a file imports from another file that is also relevant, that file gets added to the read list
- If reading a file reveals unexpected structure or patterns, the AI notes this before continuing
- The AI does not form opinions or solutions while reading — this phase is observation only

> **Sho
