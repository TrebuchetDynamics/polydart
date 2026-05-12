---
name: polydart-grill-me
description: Polydart-specific grilling session for proposed SDK, protocol, release, and workflow changes. Use when the user wants to stress-test a Polydart plan, API shape, mode boundary, wallet flow, Polygolem parity decision, or Dart/Flutter ergonomics before implementation.
---

# Polydart Grill Me

Interview the user until the proposed change is sharp enough to implement safely.
Follow the shared operating model in `../references/operating-model.md`.

Ask one question at a time. For each question, include your recommended answer
and why. If the answer can be discovered from the repo, inspect the repo instead
of asking.

## First Pass

1. Restate the change in Polydart terms: module, public API, mode, protocol
   surface, and expected consumer.
2. Check `README.md`, `docs/PLAN.md`, `docs/PRD.md`, and relevant
   `lib/src/*` and `test/*` files before questioning.
3. If the change touches protocol behavior, inspect canonical `polygolem/`
   and record the Polygolem commit being used.
4. Identify whether the work is read-only, paper-only, live-write, signing,
   release, fixture, or tooling work.

Use this skill as a gate for large or ambiguous parity work, especially public
API shape, wallet-mediated signing, live writes, release policy, multi-module
gaps, or intentional Dart divergences.

## Questions To Resolve

- What exact user-facing behavior changes?
- Which Polygolem behavior is the source of truth?
- Which Polydart mode should allow it: `readOnly`, `paper`, or `live`?
- What credentials, if any, are required?
- What must never happen accidentally: network writes, signing, secret logging,
  live retry, stale fixture use, or API drift?
- What test proves this works without hitting live write endpoints?
- What release or changelog note will future agents need?

## Done Criteria

Stop grilling only when the implementation target, safety boundary, test seam,
and Polygolem parity source are explicit. Summarize the agreed decision in
short bullets before implementation starts.
