# Git & Version Control Protocol

This document defines the mandatory Git workflow for this project.

The AI assistant is responsible for following these rules automatically unless explicitly instructed otherwise.

---

# Core Principle

Git is the source of truth for project history.

Every meaningful change must be recoverable.

Never leave the repository in an unknown state.

---

## Existing Projects

If this project already contains code but is not under Git version control:

- Initialize Git.
- Create a baseline commit representing the current state.
- Push to the configured remote repository.
- Create a baseline tag.
- Do not rewrite history.
- Treat this baseline as the project's recovery point.

# Project Initialization

When starting a brand-new project:

1. Initialize a Git repository if one does not already exist.
2. Create a `.gitignore` appropriate for the technology stack.
3. Create the initial commit.

Suggested commit:

```
chore: initial project setup
```

If Git already exists, do not reinitialize it.

---

# Repository Creation

If GitHub access is available and permission has been granted:

* Create a remote repository using the project name.
* Connect the local repository.
* Push the initial commit.
* Set the default branch to `main`.

Never create duplicate repositories.

---

# Commit Policy

Create commits automatically.

Do not wait for the user to ask.

Commit after:

* completing a feature
* fixing a bug
* refactoring
* UI improvements
* dependency updates
* architecture changes
* documentation updates

Avoid giant commits.

Prefer many small commits.

---

# Commit Message Convention

Use Conventional Commits.

Examples:

```
feat: add note search

feat: implement widgets

fix: keyboard overlap

fix: crash on launch

ui: redesign toolbar

perf: optimize scrolling

docs: update roadmap

refactor: simplify note storage

test: add search tests

chore: update dependencies
```

Never use vague messages like:

```
update

changes

fix

done

misc
```

---

# Commit Frequency

If multiple unrelated tasks are completed:

Create multiple commits.

One feature = one commit.

One bug fix = one commit.

---

# Branch Strategy

Never develop directly on main for risky work.

For new work create:

```
feature/<name>
```

Examples:

```
feature/search

feature/widgets

feature/settings
```

For fixes:

```
fix/search

fix/database
```

For experiments:

```
experiment/liquid-glass
```

Merge into main only after validation.

Delete merged branches.

---

# Before Every Commit

Verify:

* project builds
* no obvious errors
* existing functionality preserved
* no accidental deletions
* no unrelated modifications

If validation fails:

Do not commit.

---

# Before Risky Refactors

Create a safety checkpoint first.

Example:

```
git commit -m "checkpoint: before storage refactor"
```

Never begin large migrations without a rollback point.

---

# Automatic Push Policy

If remote exists:

Push after every successful commit.

```
git push
```

Do not leave local commits unpushed unless requested.

---

# Version Tags

For important milestones create tags.

Examples:

```
v0.1

v0.2

v1.0

beta1

release-2026-06
```

Push tags to remote.

---

# Rollback Strategy

If a change introduces instability:

Prefer reverting to the most recent stable commit.

Never rewrite history unless explicitly instructed.

Preserve recoverability.

---

# Destructive Operations

Never automatically:

* force push
* delete branches
* rewrite history
* squash commits
* rebase shared history
* delete tags

Require explicit user approval.

---

# Recovery

If uncertainty exists:

Create a checkpoint commit before continuing.

It is better to have too many checkpoints than too few.

---

# AI Responsibilities

The AI should actively maintain repository health.

It should:

* initialize Git when appropriate
* create repositories when authorized
* commit regularly
* push regularly
* use meaningful messages
* create safety checkpoints
* recommend tags
* recommend branches
* preserve history

Git should be treated as an automatic safety system rather than an optional tool.

---

# Guiding Philosophy

The user should always be able to return to any previous working state.

Every commit should represent a meaningful step in the evolution of the project.

History should tell the complete story of how the software was built.
