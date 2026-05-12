---
name: polydart-skill-manager
description: Maintain the Polydart development skill pack. Use when creating, editing, validating, installing, renaming, deprecating, or reviewing skills under skills/polydart.
---

# Polydart Skill Manager

Keep Polydart skills compact, discoverable, and specific to this repo.
Follow the shared operating model in `../references/operating-model.md`.

## Layout

Use:

```text
skills/polydart/<name>/
  SKILL.md
  agents/openai.yaml
```

Add `references/`, `scripts/`, or `assets/` only when the skill needs reusable
material that should not live in `SKILL.md`.
Repo-local `skills/polydart` is canonical. Installed copies, if any, are
derived artifacts.

## Creation Rules

1. Name skills `polydart-<purpose>` using lowercase hyphen-case.
2. Initialize with the Codex skill creator script when possible.
3. Keep `SKILL.md` under 100 lines unless a reference file is justified.
4. Put trigger language in frontmatter: the description must include
   `Use when ...`.
5. Keep body instructions imperative and repo-specific.
6. Remove every generated placeholder before validation.
7. Keep `agents/openai.yaml` default prompts using the literal `$skill-name`.
8. Put shared rules in `references/operating-model.md`, not duplicated prose.
9. Keep public repo artifacts free of non-public customer, deployment, or
   alpha-program names.

## Validation

Run the validator for each changed skill:

```sh
python3 /home/xel/.codex/skills/.system/skill-creator/scripts/quick_validate.py skills/polydart/<name>
```

Then scan:

```sh
rg '\\[T]ODO|Use\\s+-' skills/polydart
rg -i '[a]renaton|owner[- ]alpha|private[ -]product|internal[ -]customer' skills/polydart docs
python3 skills/polydart/scripts/test_polygolem_inventory.py
```

Treat existing private-name hits outside touched files as cleanup backlog, but
do not introduce new hits.

## Review Standard

A Polydart skill should encode non-obvious process: Polygolem parity, Dart test
seams, protocol safety, release lockstep, or repo-specific commands. Do not
create generic skills that merely restate normal engineering practice.
After broad skill edits, forward-test with a fresh agent when available.
