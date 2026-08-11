---
name: git-branch-manager
description: >
  Universal Git branch management skill for any project — existing or brand new.
  Invoke whenever the user says: "I am done with X", "start working on Y",
  "create a branch for Z", "this is just for testing", "commit my changes",
  "push my work", "the build is failing", or any time git workflow is needed.
  Automatically discovers project state, identifies the foundation branch,
  applies correct naming, commit conventions, merge protocol, and push policy.
  Also diagnoses and fixes cross-branch dependency failures (missing files,
  missing methods caused by being on the wrong branch).
risk: safe
source: local
date_added: "2026-08-11"
---

# Universal Git Branch Manager

> Works for any project — existing repos with history, brand new projects,
> Flutter/Dart, Node.js, Python, React, or any other stack.
> The first thing this skill does is read the project. It never assumes.

---

## PHASE 0 — Project Discovery (Always Run First)

Before any git action, run these commands and read the output:

```bash
# 1. Check if git exists
git status

# 2. List all branches
git branch -a

# 3. Read recent history
git log --oneline -20

# 4. Check for uncommitted work
git diff --stat
git status --short
```

From these outputs, answer:
- Is this a **new project** (no git yet) or an **existing project**?
- What is the **current branch**?
- Are there **uncommitted changes**?
- Does the project have a **foundation branch** (see Section 2)?
- What **tech stack** is this? (Flutter, Node, Python, etc. — determines what files to watch for)

> Do NOT proceed to any other section until you have answered all five questions.

---

## PHASE 1 — New Project vs Existing Project

### 1A. Brand New Project (no git repo yet)

```bash
# Initialize git
git init

# Create .gitignore appropriate for the tech stack
# Flutter:    .gitignore with build/, .dart_tool/, .flutter-plugins, pubspec.lock (optional)
# Node.js:    .gitignore with node_modules/, dist/, .env
# Python:     .gitignore with __pycache__/, .venv/, *.pyc, .env
# React/Vite: .gitignore with node_modules/, dist/, .env

# Create the first commit
git add .
git commit -m "chore: initial project setup"

# Set up remote if available
git remote add origin <url>
git push -u origin main

# Tag the starting point
git tag v0.1-init
git push origin v0.1-init
```

Then proceed to Section 3 to create the first feature branch.

### 1B. Existing Project (git repo already present)

Run the diagnostic in PHASE 0, then:

1. **Identify the foundation branch** (Section 2)
2. **Check which branch you are on** before doing anything
3. **Stash or commit** any open changes before switching branches

---

## 2. Identifying the Foundation Branch

The **foundation branch** is the branch that contains the most critical shared infrastructure — the one that, if you are NOT on it (or have NOT merged it), the build breaks.

### How to identify it automatically

```bash
# Look for the branch with the most files in critical infrastructure directories
git log --all --oneline --name-status | grep "^A" | sort | uniq -c | sort -rn

# Find which branch introduced core service/model files
git log --all --oneline -- lib/services/ lib/models/ lib/repositories/ src/services/ src/models/
```

### Signs a branch IS the foundation branch
- It added: core services, database layer, authentication, models, repositories
- Other branches break (missing file errors) when they do NOT have this branch merged
- It was the last "big architecture" commit

### Signs a branch is NOT safe to branch from (missing foundation)
- Build errors: `Error when reading '<file>': The system cannot find the file specified`
- Compiler errors: `Method not found: '<methodName>'`
- Type errors: `Type '<ClassName>' not found`

### What to do when foundation is missing
```bash
# Stash open work
git stash

# Merge the foundation branch into current branch
git merge <foundation-branch-name>

# Restore open work
git stash pop
```

---

## 3. Branch Naming Convention (Universal)

| Situation | Pattern | Examples |
|-----------|---------|---------|
| New screen / major feature | `feature/<name>` | `feature/search-screen`, `feature/user-auth` |
| Bug fix | `fix/<what>` | `fix/login-crash`, `fix/data-not-saving` |
| Refactor (no behavior change) | `refactor/<what>` | `refactor/database-layer` |
| Experimental / testing only | `experiment/<name>` | `experiment/new-animation`, `experiment/ai-search` |
| Performance improvement | `perf/<what>` | `perf/list-scroll`, `perf/image-loading` |
| UI / visual only (no logic) | `ui/<what>` | `ui/home-redesign`, `ui/typography-pass` |
| Documentation / skill update | `docs/<what>` | `docs/architecture`, `docs/api-reference` |
| Build / config / tooling | `chore/<what>` | `chore/gradle-upgrade`, `chore/ci-setup` |

**Rules:**
- Use lowercase with hyphens only
- Be descriptive — `feature/search-screen` not `feature/s` 
- Never develop directly on `main` or `master`

---

## 4. Creating a Branch — Universal Step-by-Step

### Step 1 — Make sure current work is clean
```bash
git status
# If changes exist → commit or stash them
```

### Step 2 — Identify the correct base branch

Ask: *"What is the most recent stable branch that has all core infrastructure?"*

```bash
# Check what's on each candidate branch
git log <candidate-branch> --oneline -5
```

For **new features**: branch from the latest stable feature branch (not `main` if main is behind).  
For **bug fixes**: branch from the branch where the bug exists.  
For **experiments**: branch from wherever — it will be thrown away anyway.

### Step 3 — Create and switch
```bash
git checkout <base-branch>
git pull origin <base-branch>       # ensure it is up to date
git checkout -b <new-branch-name>
```

### Step 4 — Verify foundation is present
```bash
# Run a quick build/compile check
# Flutter:   flutter analyze
# Node:      npm run build
# Python:    python -m py_compile src/main.py
```

If errors appear about missing files → run foundation merge (Section 2).

### Step 5 — Push immediately to register on remote
```bash
git push -u origin <new-branch-name>
```

---

## 5. Commit Policy

### When to commit — do it after ANY of these:
- ✅ A feature or screen is working (even partially)
- ✅ A bug is fixed
- ✅ A class, service, or repository is created
- ✅ A changelog or documentation is written
- ✅ Before switching to a different branch or feature
- ✅ At the end of every session, regardless of completion

### Commit Message Format — Conventional Commits (universal)

```
<type>(<scope>): <imperative short description>
```

| Type | Use for |
|------|---------|
| `feat` | New feature, screen, or capability |
| `fix` | Bug fix |
| `ui` | Visual / design only change |
| `style` | Code style, formatting (no logic change) |
| `refactor` | Internal restructuring, no behavior change |
| `perf` | Performance improvement |
| `docs` | Documentation, changelogs, READMEs, skills |
| `chore` | Build config, dependency updates, tooling |
| `test` | Adding or fixing tests |

**Scope** = the feature area or module affected (optional but recommended):
`auth`, `database`, `search`, `editor`, `home`, `navigation`, `tasks`, `api`

**Good examples (any project):**
```
feat(auth): implement biometric login with fallback PIN
fix(database): resolve migration failure on schema v5 to v6
ui(home): align card spacing to match Figma spec
docs(skills): add git-branch-manager universal skill
chore(deps): upgrade flutter_local_notifications to 22.0.0
refactor(tasks): extract scheduling logic into TaskEngine service
perf(list): add RepaintBoundary to NoteCard to reduce frame drops
```

**Forbidden messages:**
```
❌  update
❌  changes  
❌  fix
❌  done
❌  misc
❌  wip
❌  asdf
❌  temp
```

### Pre-commit checklist
```
[ ] Code compiles / analyzes without errors
[ ] I am on the correct branch for this feature
[ ] Only files related to THIS feature are staged
[ ] Commit message follows Conventional Commits format
[ ] No debug prints, test seeds, or hardcoded test data committed unintentionally
```

---

## 6. Handling Uncommitted Work When Switching Context

### Option A — Checkpoint commit (preferred)
```bash
git add -A
git commit -m "checkpoint: <what is partially done>"
git push
```

### Option B — Stash
```bash
git stash push -m "wip: <description of what is saved>"
git checkout <other-branch>
# ... work on other branch ...
git checkout <original-branch>
git stash pop
```

> [!WARNING]
> Always name your stash with `-m`. Anonymous stashes are forgotten.
> Run `git stash list` periodically to check for leftover stashes.
> A stash is a safety net, not a storage system. Commit as soon as stable.

---

## 7. The Universal Build Failure Diagnostic

If the build fails with **missing file or missing type/method errors**:

### Step 1 — Identify what is missing
```bash
# Read the first error message carefully
# Pattern: "Error when reading '<path>': The system cannot find the file"
# Extract the missing file path
```

### Step 2 — Find which branch has that file
```bash
git log --all --oneline -- <missing-file-path>
# This shows every commit that ever touched that file
# The branch containing the most recent ADD (A) entry is the foundation
```

### Step 3 — Check if you are on that branch or a branch derived from it
```bash
git log --oneline | grep "<commit-description-from-step-2>"
# If it appears → you have it. The error is a different problem.
# If it does NOT appear → you are missing the foundation.
```

### Step 4 — Merge the foundation
```bash
git stash                          # save current changes
git merge <foundation-branch>      # bring in the missing files
git stash pop                      # restore your changes
```

### Step 5 — Verify fix
```bash
# Run compile/analyze again
flutter analyze   # or npm run build, or python -m py_compile, etc.
```

---

## 8. Experiment / Testing Branches

When the user says *"just for testing"*, *"I want to try something"*, *"don't want to break main"*:

```bash
# Create experiment branch
git checkout -b experiment/<name>
git push -u origin experiment/<name>

# Work freely — break things, try things
# No strict commit message rules here
# But DO commit regularly so work is not lost
```

**After testing:**

```bash
# If it WORKED → bring good commits to a proper feature branch
git checkout feature/<destination>
git cherry-pick <commit-hash-of-good-part>
git commit --amend -m "feat(<scope>): <proper message>"

# If it FAILED → clean up
git checkout <previous-branch>
git branch -d experiment/<name>
git push origin --delete experiment/<name>
```

> Never merge `experiment/` directly into `main`.

---

## 9. Merging a Completed Feature into Main

```bash
# Step 1 — Ensure feature branch is clean and pushed
git status            # should show "nothing to commit"
git push              # confirm remote is up to date

# Step 2 — Update main
git checkout main
git pull origin main

# Step 3 — Merge feature
git merge feature/<name>
# If conflicts → resolve them, then: git add -A && git commit

# Step 4 — Run final verification
# Flutter: flutter analyze && flutter test
# Node:    npm test && npm run build
# Python:  pytest

# Step 5 — Push main
git push origin main

# Step 6 — Tag if this is a release milestone
git tag v<major>.<minor>.<patch>
git push origin v<major>.<minor>.<patch>

# Step 7 — Optional: delete merged feature branch
git branch -d feature/<name>
git push origin --delete feature/<name>
```

> [!IMPORTANT]
> Never delete a feature branch until the merge is pushed AND verified on device/staging.

---

## 10. Push Policy

```bash
# After every commit → push
git push

# First push of a new branch
git push -u origin <branch-name>
```

**Never leave local commits unpushed.** The remote is your backup.  
If your machine dies, any commit not pushed is **permanently lost**.

---

## 11. "What Should I Do?" Decision Tree

```
User intent
     │
     ├─ "I want to start working on <feature>"
     │        → Check PHASE 0 → Create feature/<name> from latest stable
     │
     ├─ "I just finished <feature>"
     │        → Commit → Push → Update branch registry → Continue
     │
     ├─ "This is just for testing / experimenting"
     │        → Create experiment/<name> → Work freely → Cherry-pick if good
     │
     ├─ "The build is failing / missing files"
     │        → Run Section 7 Diagnostic → Merge foundation branch
     │
     ├─ "I want to fix a bug"
     │        → Create fix/<bug-name> from affected branch → Fix → PR or merge
     │
     ├─ "I'm done with everything / releasing"
     │        → Follow Section 9 Merge Protocol → Tag the release
     │
     └─ "I'm starting a brand new project"
              → Follow Section 1A → Init → First commit → Push → Tag
```

---

## 12. Branch Registry Template

> Copy this template into your project's SKILL.md or README and update it as branches evolve.

```markdown
## Branch Registry

| Branch | Status | Description | Has Foundation? | Created From |
|--------|--------|-------------|-----------------|--------------|
| `main` | Stable | Production releases | ✅ | — |
| `feature/<name>` | Active | <description> | ✅/⚠️ | `<base>` |
```

**Status values:**
- `Stable` — merged into main, fully tested
- `Active` — current development target
- `Paused` — temporarily stopped, will resume
- `Abandoned` — not continuing, do not branch from this

---

## 13. Quick Reference Card

```
WHAT YOU WANT                          COMMAND
───────────────────────────────────────────────────────────────────────
See current branch                     git branch
See all branches                       git branch -a
See recent commits                     git log --oneline -15
See uncommitted changes                git status
Find who introduced a file             git log --all --oneline -- <file>
Create new branch                      git checkout -b <name>
Switch to existing branch              git checkout <name>
Merge another branch in                git merge <branch>
Stage specific files                   git add <file1> <file2>
Stage everything                       git add -A
Commit                                 git commit -m "<type>(<scope>): <msg>"
Push (first time)                      git push -u origin <branch>
Push (subsequent)                      git push
Save without committing                git stash push -m "<desc>"
List stashes                           git stash list
Restore latest stash                   git stash pop
Tag a release                          git tag v<x>.<y>.<z> && git push origin --tags
Delete local branch                    git branch -d <name>
Delete remote branch                   git push origin --delete <name>
```

---

## 14. Project-Specific Notes (Auto-filled on first use)

When this skill is first applied to a project, fill in this section:

```
Project Name:         <fill in>
Tech Stack:           <Flutter / Node / Python / React / etc.>
Foundation Branch:    <fill in — the branch all others depend on>
Latest Stable Branch: <fill in — branch new features should base from>
Remote URL:           <fill in>
Build Verify Command: <flutter analyze / npm run build / pytest / etc.>
Critical Files:       <list files whose absence breaks the build>
```

### QuickNotes Project — Filled In

```
Project Name:         Quick Notes
Tech Stack:           Flutter / Dart 3 / Android
Foundation Branch:    feature/production-data-architecture
Latest Stable Branch: feature/search-screen  (as of 2026-08-11)
Remote URL:           https://github.com/HemanthAdapala/QuickNotes.git
Build Verify Command: flutter analyze
Critical Files:
  - lib/controllers/splash_controller.dart
  - lib/controllers/login_controller.dart
  - lib/data/sqlite_profile_repository.dart
  - lib/views/widgets/rich_text_controller.dart (shiftOffsetsSilently @ line 2319)
```
