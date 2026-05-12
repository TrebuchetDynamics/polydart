---
name: polydart-git
description: Git and repository hygiene for Polydart development. Use when preparing branches, commits, submodules, Polygolem reference updates, generated fixture changes, or safe commit slicing in the Polydart repo.
---

# Polydart Git

Keep Polydart changes small, attributable, and safe around the Polygolem
reference repos.
Follow the shared operating model in `../references/operating-model.md`.

## Start

Run:

```sh
git status --short
git branch --show-current
git submodule status
git -C polygolem rev-parse --short HEAD
git -C .reference/polygolem rev-parse --short HEAD
```

Treat uncommitted user changes as owned by the user. Do not revert them. If
they affect the task, work around them or ask for direction.

## Reference Repos

- `polygolem/` is the canonical upstream submodule.
- `.reference/polygolem/` is a legacy reference used by existing docs.
- Never edit, patch, or commit inside either upstream checkout.
- Before protocol work, refresh only when appropriate:

```sh
git -C polygolem pull --ff-only origin main
git -C .reference/polygolem pull --ff-only
```

Record the exact Polygolem commit in tests, notes, or the changelog when it is
used for parity work.
If the submodule pointer changes, stage that separately from Polydart feature
ports unless the user asks for one combined change.

## Commit Slicing

Prefer separate commits for:

- Submodule or reference updates.
- Protocol implementation changes.
- Fixture updates.
- Skill-pack maintenance.
- Release metadata.

Before finalizing, run the narrowest useful verification first, then the full
Polydart checks when behavior changed:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-warnings
dart test --reporter=expanded
```
