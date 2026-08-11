---
name: git-branch-manager
description: >
  QuickNotes project-specific Git branch management skill. Invoke whenever the
  user says: "I am done with X", "start working on Y", "create a branch for Z",
  "this is just for testing", "commit my changes", "push my work", or whenever
  a build fails with missing file errors. Covers branch creation, the correct
  base branch rule, commit policy, merge protocol, push policy, and the specific
  cross-branch dependency trap this project has already hit.
risk: safe
source: local
date_added: "2026-08-11"
---

# QuickNotes Git Branch Manager

> This is the most important operational skill for this project.
> Every build failure from a "missing file" error has been caused by being
> on the wrong branch. This skill prevents that from ever happening again.

---

## 0. ALWAYS RUN THIS FIRST — Branch Health Check

Before touching any code, creating any branch, or committing anything, run:

```powershell
git status
git branch
```

Then answer these three questions:

1. **What branch am I on?**
2. **Does this branch have `feature/production-data-architecture` merged into it?**
3. **Are there uncommitted changes that belong to a different feature?**

If you cannot answer all three — STOP and run the diagnostic in Section 7.

---

## 1. The Golden Rule — The Foundation Branch

`feature/production-data-architecture` is the **foundation branch**.

It contains:
- `lib/controllers/splash_controller.dart`
- `lib/controllers/login_controller.dart`
- `lib/data/sqlite_profile_repository.dart`
- Full `RichTextEditingController` with `shiftOffsetsSilently`
- Full 4-tier data architecture (repositories, providers, statistics service)
- Android package ID (`com.quicknotes.app`)

**Every new feature branch MUST be created from, or have merged, `feature/production-data-architecture`.**

> [!CAUTION]
> The build failure on 2026-08-11 was caused by creating work on
> `feature/drag-selection-and-contextual-toolbar` which pre-dated the foundation
> branch. Missing file errors for `splash_controller.dart`, `login_controller.dart`,
> and `sqlite_profile_repository.dart` are the symptom. Wrong branch is ALWAYS
> the cause.

---

## 2. Current Branch Registry

Keep this table up to date every time a branch is created or merged.

| Branch | Status | Description | Has Foundation? |
|--------|--------|-------------|-----------------|
| `main` | Stable | Production releases only | ✅ |
| `feature/production-data-architecture` | Foundation | 4-tier data architecture, controllers, repositories | ✅ (IS the foundation) |
| `feature/home-redesign` | Active | Home screen and navigation shell redesign | ⚠️ Verify before use |
| `feature/android-build-configuration` | Active | Package ID + Gradle + Firebase | ✅ |
| `feature/drag-selection-and-contextual-toolbar` | Active | SingleDocumentDragOverlay + text selection | ✅ (merged after 2026-08-11) |
| `feature/image-engine-rewrite` | Active | Inline image engine rewrite | ⚠️ Verify before use |
| `feature/search-screen` | Active | Global Search Screen v1+v2 | ✅ |

> **To verify if a branch has the foundation merged**, run:
> ```powershell
> git log --oneline | Select-String "4-tier SQLite production architecture"
> ```
> If it appears — ✅ safe. If not — merge foundation first.

---

## 3. Branch Naming Convention

Follow this naming scheme exactly:

| Situation | Branch Name Pattern | Example |
|-----------|-------------------|---------|
| New screen or major UI feature | `feature/<screen-name>` | `feature/calendar-screen` |
| Bug fix | `fix/<what-is-broken>` | `fix/search-highlight-crash` |
| Refactor | `refactor/<what>` | `refactor/task-engine` |
| Experimental / testing only | `experiment/<name>` | `experiment/liquid-glass-dock` |
| Performance work | `perf/<what>` | `perf/note-list-scroll` |
| Documentation update | `docs/<what>` | `docs/architecture-update` |
| UI/Design only (no logic) | `ui/<what>` | `ui/home-screen-tweaks` |

**Never develop directly on `main`.**

---

## 4. Creating a New Branch — Step by Step

### Step 1 — Verify current branch has no pending work
```powershell
git status
```
If there are uncommitted changes → commit or stash them first (see Section 6).

### Step 2 — Ensure you are starting from the right base

**For any new feature work:**
```powershell
git checkout feature/search-screen   # or the most recent stable feature branch
git pull origin feature/search-screen
```

> Always branch from the **most recent feature branch that has the foundation merged**.
> Today (2026-08-11) that is `feature/search-screen`.
> Update this as new branches become the "latest stable".

### Step 3 — Create the branch
```powershell
git checkout -b feature/<name>
```

### Step 4 — Verify foundation is present
```powershell
git log --oneline | Select-String "4-tier SQLite"
```
Should print a result. If not, merge foundation:
```powershell
git merge feature/production-data-architecture
```

### Step 5 — Push immediately to remote to register it
```powershell
git push -u origin feature/<name>
```

---

## 5. Commit Policy

### When to commit
Commit automatically after ANY of these:
- ✅ A new screen is implemented
- ✅ A bug is fixed
- ✅ A UI change is visible and working
- ✅ A service or repository class is created
- ✅ A refactor is complete
- ✅ A changelog is written
- ✅ Before switching to a different feature or branch

### Commit Message Format — Conventional Commits

```
<type>(<scope>): <short description>
```

| Type | When to use |
|------|------------|
| `feat` | New feature or screen |
| `fix` | Bug fix |
| `ui` | Visual / design only change |
| `style` | Spacing, colors, typography (no logic) |
| `refactor` | Internal restructure, no behavior change |
| `perf` | Performance improvement |
| `docs` | Changelog, README, skill updates |
| `chore` | Build config, pubspec, gradle |
| `test` | Test files only |

**Scope** = the affected file or feature area (lowercase):
`search`, `editor`, `tasks`, `calendar`, `home`, `vault`, `auth`, `database`, `toolbar`, `navigation`

**Examples:**
```
feat(search): implement scope pill selector with animated active state
fix(editor): resolve shiftOffsetsSilently missing from RangeTextEditingController
ui(home): adjust prompt view spacing to match Figma
docs(changelog): add SearchScreen_Changelog.md v2.0.0 entry
chore(android): update applicationId to com.quicknotes.app
```

### Before every commit — verification checklist
```
[ ] flutter analyze shows no errors (run: flutter analyze)
[ ] I am on the correct feature branch
[ ] My changes are scoped to this branch's feature
[ ] No unrelated files are staged
[ ] The commit message describes WHAT changed and WHY (not just "update")
```

### Never use vague messages
```
❌ update
❌ changes
❌ fix
❌ done
❌ misc
❌ wip
```

---

## 6. Handling Uncommitted Changes When Switching Context

If you need to switch branches but have uncommitted work:

### Option A — Commit it (preferred)
```powershell
git add <files>
git commit -m "checkpoint: <description of incomplete state>"
```

### Option B — Stash it
```powershell
git stash                           # saves current changes
git checkout <other-branch>         # switch
# ... do work on other branch ...
git checkout feature/<your-branch>  # come back
git stash pop                       # restore your changes
```

> [!WARNING]
> NEVER stash and forget. Always `git stash list` to check for lingering stashes.
> A stash is temporary. Commit the work properly when it's stable.

---

## 7. Diagnostic — "Build is Failing with Missing File Errors"

If you see errors like:
```
Error when reading 'lib/controllers/splash_controller.dart': The system cannot find the file specified
Error when reading 'lib/controllers/login_controller.dart': The system cannot find the file specified
Error when reading 'lib/data/sqlite_profile_repository.dart': The system cannot find the file specified
Method not found: 'shiftOffsetsSilently'
```

**Run this diagnostic immediately:**

```powershell
# Step 1 — What branch are you on?
git branch

# Step 2 — Does this branch have the foundation?
git log --oneline | Select-String "4-tier SQLite production architecture"

# Step 3 — If the foundation is missing, merge it
git stash                                        # save any uncommitted changes
git merge feature/production-data-architecture   # bring in the foundation
git stash pop                                    # restore your changes
```

This fixes 100% of "missing file" build failures in this project.

---

## 8. Push Policy

Push after every successful commit:
```powershell
git push
```

If upstream is not set (new branch):
```powershell
git push -u origin feature/<name>
```

> Never leave local commits unpushed. Remote is the backup.
> If the machine dies, local commits that were not pushed are lost forever.

---

## 9. Experiment / Testing Branches

When the user says "just for testing", "I want to try something", or "experiment with X":

1. Create an `experiment/` branch
2. Work freely — no strict commit requirements
3. When done testing:
   - If it worked → cherry-pick or merge the good parts into a `feature/` branch
   - If it didn't → delete the branch (`git branch -d experiment/<name>`)
4. NEVER merge an `experiment/` branch directly into `main` or a stable `feature/` branch

```powershell
# Create experiment branch
git checkout -b experiment/<name>
git push -u origin experiment/<name>

# After testing — if it worked, bring the good commits to feature branch
git checkout feature/<destination>
git cherry-pick <commit-hash>

# If it didn't work — clean up
git checkout feature/<previous-branch>
git branch -d experiment/<name>
git push origin --delete experiment/<name>
```

---

## 10. Merging a Completed Feature

When a feature is fully done and tested:

```powershell
# Step 1 — Make sure feature branch is clean and pushed
git status        # should show "nothing to commit"
git push          # ensure remote is up to date

# Step 2 — Switch to main
git checkout main
git pull origin main

# Step 3 — Merge the feature branch
git merge feature/<name>

# Step 4 — Push main
git push origin main

# Step 5 — Tag if it is a milestone release
git tag v<version>
git push origin v<version>

# Step 6 — Delete the feature branch (optional, after confirming merge)
git branch -d feature/<name>
git push origin --delete feature/<name>
```

> [!IMPORTANT]
> Never delete a feature branch until it is confirmed merged into `main`
> AND the app has been verified on device post-merge.

---

## 11. The "What Branch Should I Be On?" Decision Tree

```
User says: "I want to work on <X>"
                │
                ▼
    Is X a bug fix on existing working code?
                │
       Yes ─────┤──── No
                │           │
                ▼           ▼
          fix/<bug>    Is X a new screen or feature?
                                │
                       Yes ─────┤──── No
                                │           │
                                ▼           ▼
                         feature/<name>  Is X experimental/testing?
                                                │
                                       Yes ─────┤──── No
                                                │           │
                                                ▼           ▼
                                         experiment/<name>  ui/<name> or perf/<name>

In ALL cases:
→ Verify git log shows "4-tier SQLite" before writing any code
→ If missing → git merge feature/production-data-architecture
→ Push branch to remote immediately after creating it
```

---

## 12. Quick Reference Card

```
SITUATION                          COMMAND
─────────────────────────────────────────────────────────────────
Check current branch               git branch
Check if foundation is present     git log --oneline | Select-String "4-tier SQLite"
Create new feature branch          git checkout -b feature/<name>
Merge foundation if missing        git merge feature/production-data-architecture
Save changes without committing    git stash
Restore stashed changes            git stash pop
Stage all relevant files           git add <file1> <file2>
Commit                             git commit -m "feat(<scope>): <description>"
Push (first time)                  git push -u origin feature/<name>
Push (subsequent)                  git push
Check for uncommitted changes      git status
View recent commits                git log --oneline -10
Switch to existing branch          git checkout feature/<name>
```

---

## 13. Current "Latest Stable" Branch

> **Update this section every time a major feature is completed and merged.**

As of **2026-08-11**, the latest stable branch that has ALL core infrastructure is:

```
feature/search-screen
```

**All new feature branches should be created FROM `feature/search-screen`.**

It contains:
- ✅ 4-tier production data architecture
- ✅ Splash & Login controllers
- ✅ SQLite profile repository
- ✅ Full `RichTextEditingController` with `shiftOffsetsSilently`
- ✅ Android package config (`com.quicknotes.app`)
- ✅ SelectionDragOverlay QA sprint
- ✅ Global Search Screen (v1 + v2)
- ✅ Task Engine (Milestone 1 complete)
- ✅ Home Screen redesign (merged)
