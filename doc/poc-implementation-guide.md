# PoC Implementation Guide

> **Audience:** implementation agents building the PoC, likely via a dynamic/self-directed workflow.
> **Nature of this guide:** key points, gates, and guardrails — **not a recipe.** You decide the specific commands, file layout, and library micro-choices at implementation time. Where this guide and reality disagree, reality wins: verify, then update the docs.
> **Companion doc:** `doc/agent-development-loop.md` holds the verified specifics (test commands, exit codes, the embedded capture script + MCP servers, headless gotchas, pitfalls, references). Read it first. This guide tells you *what to achieve and what not to break*; that doc tells you *what's known to work* — **it is the prescriptive single source of truth for specifics. If the two ever disagree, it wins and this guide gets updated.**

Last updated: 2026-06-17.

---

## 0. How to operate

- **Verify, don't guess.** If a command, flag, or tool behavior is uncertain, run it and confirm before relying on it. Unverified claims in the companion doc are listed under its "Open Items" — treat them as hypotheses to test, not facts.
- **Smallest real slice.** The PoC's product is a *proven loop*, not game content. Prefer the minimum that exercises the loop end to end.
- **Keep the docs honest.** When you confirm/contradict something or make a decision, update `doc/agent-development-loop.md` and add a Changelog line. The next agent inherits whatever you leave.
- **Stop on real blockers.** If the environment is missing pieces a headless agent can't install (engine, GPU, signing), stop and report to the human PM — don't fake or mock your way around the thing the PoC is meant to prove.

## 1. What the PoC must prove (Definition of Done)

The loop **closes on this machine**: the agent can change code, have a **logic** defect caught by headless tests, fix it, then have a **visual/runtime** defect caught by a screenshot/error read, and fix that — without a human running anything in between. Concretely, "done" = you can demonstrate, on a deliberately broken change, that:

1. a logic bug is caught at the **test** layer (not the visual layer), and
2. a render/runtime bug is caught at the **visual** layer (not the test layer), and
3. both are fixed and the slice ends green and visually correct.

If you can show that once, the PoC succeeds. Everything else is scope creep.

## 2. Non-negotiables (do not decide these away)

- **GDScript, not C#. 2D, not 2.5D/3D.** Godot 4.6 idioms (`await` not `yield`, `CharacterBody2D` not `KinematicBody2D`, static typing). These are locked decisions.
- **Both loop parts are required.** Never sign off on headless tests alone — headless can pass while a GPU run crashes. The visual/runtime check is mandatory before "done."
- **Logic lives in pure, GUI-free functions.** If a rule can't be tested without instantiating a scene, refactor until it can. This is what makes the agent self-sufficient.
- **Don't corrupt scene identity.** Prefer editor / scene-builder scripts over raw `.tscn` rewrites that can break `uid://` tracking.
- **Humans own fun and balance.** Verify correctness (it fires, it renders, it doesn't crash); surface design/balance questions to the PM rather than silently deciding them.
- **Don't reopen locked decisions** (engine, language, dimensionality) without the PM.

## 3. Decisions you own (pick the best option while implementing)

These are deliberately left open — choose, then record what you chose and why:

- **Test framework:** gdUnit4 (doc's recommendation) vs GUT. Switch if you hit real friction.
- **Part B observation:** the embedded GDScript capture script is the primary path (companion doc §5); you own *whether/when* to add a visual MCP server on top — only if you need interactive scene queries or input injection.
- **Project/folder structure and naming.**
- **Card/state data modeling:** `.tres` resources vs JSON vs plain `RefCounted` classes.
- **Test granularity and how much CI to wire up now** (a green local CLI run may be enough for the PoC; full CI can wait).
- **Exactly which "deliberate bug" demonstrates each layer.**

When a choice is reversible and low-cost, just make it and note it. When it's hard to reverse or shapes later work, flag it to the PM.

## 4. Milestones (intent + acceptance gate; you fill in the how)

**M0 — Environment proven.** Engine and test framework present and reachable; the embedded capture script can run.
- *Gate:* an empty/trivial headless test runs and reports a result, **and** the capture script can launch a scene and write one screenshot to disk. Until both hold, you are not building the PoC — you are setting up.

**M1 — Logic backbone (Part A).** One real, pure-function rule with a unit test (e.g. "play card → new state").
- *Gate:* test passes headless via the CLI with the correct success exit code and a report artifact; the headless import gotchas in the companion doc are handled.

**M2 — Visual slice (Part B).** A minimal scene that reflects that state on screen (e.g. one card + one hex tile).
- *Gate:* the capture script launches the scene and writes a screenshot showing the expected elements, with no runtime errors reported.

**M3 — Closed-loop proof.** Introduce one deliberate logic bug **and** one deliberate visual bug.
- *Gate:* each is caught at the correct layer (logic→tests, visual→screenshot/error), both are fixed, slice ends green and correct. This gate is the Definition of Done.

**M4 — Capture learnings.** Fold what actually happened back into `doc/agent-development-loop.md`: confirmed/corrected commands, timings, friction, and any decision you made from §3.

Milestones are ordered by dependency, not mandated as separate workflow phases — a dynamic workflow may interleave them, but **don't claim a later gate before an earlier one holds.**

## 5. Scope boundaries (explicitly out of scope for the PoC)

No real content; no art pipeline; no full hex map or fog system; no event/economy systems; no mobile/desktop export; no Steam/IAP. One card, one tile, one rule, one loop. Resist building the game — build the proof.

## 6. When to stop and ask the human

- Environment pieces can't be installed/verified in-session (engine, GPU rendering, code signing).
- A non-negotiable (§2) appears to be in tension with making progress — surface it; don't quietly relax it.
- A §3 decision turns out to be hard-to-reverse or to constrain the real game's architecture.
- The loop *cannot* be closed on this machine after honest effort — that's a finding worth reporting, not a failure to hide.

## 7. Agent operating contract (how a Claude Code run consumes this)

This is the *checkable* layer under §4 — it turns each gate into an objective signal and names what each phase emits, so an agent (or workflow) can run it step-for-step.

**Precondition — where this can run.** The loop needs a real Godot 4.6 install + a display/GPU. It runs on the developer's Mac, **not in a headless cloud session** — M0 hard-stops otherwise. A run that can't reach the engine stops at M0 and reports; that's a correct outcome, not a failure (§6).

**Load order.** Read the companion doc (`agent-development-loop.md`) first — prescriptive source for commands, the capture script, and gotchas. This guide supplies gates + guardrails.

**Judge from the artifact, not the code** — a gate passes on the screenshot / exit code / stdout it produced, never on "it compiled" (companion doc §3).

| Milestone | Pass signal (objective) | Emits |
|---|---|---|
| **M0** | gdUnit4 trivial test exits `0` **and** ran ≥1 test (not "no tests found"); capture script writes a PNG to disk | `PLAN.md`, `STRUCTURE.md`; baseline screenshot path |
| **M1** | `runtest.sh -a` exits `0` (pass) + report artifact exists; headless import warm-up handled (companion §4) | test path, report dir, exit code |
| **M2** | capture-script PNG, judged against the companion doc's **screenshot defect taxonomy (§3)** — clipping / scale / missing-asset / z-index — with `ASSERT PASS` and no `ASSERT FAIL` in stdout | scene path, screenshot path |
| **M3** | logic bug → caught at test layer (exit `100`); visual bug → caught via screenshot / `ASSERT FAIL`; both fixed → exit `0` + taxonomy-clean | before/after screenshots, the demonstrated diff |
| **M4** | companion doc updated (commands / timings / §3 decisions) + Changelog line | doc diff |

**Workflow shape.** Sequential gated pipeline, not a fan-out — prefer **one driver agent stepping M0→M4 with a todo list**, persisting state to `PLAN.md` / `MEMORY.md` after each gate (companion doc §6b). Reach for a multi-agent Workflow only where real parallelism appears (e.g. fanning out deliberate-bug candidates, or multi-lens screenshot verification).

**Hard stops** (§6): missing engine/GPU, a non-negotiable in tension, a hard-to-reverse §3 decision, or an un-closable loop → stop and report; don't mock around the thing the PoC proves.

## Changelog
- **2026-06-17** — Guide created. Principle-level; defers specifics to implementing agents and to `doc/agent-development-loop.md`.
- **2026-06-17** — depandabot audit (reviewer: Codex) → **PROCEED_AMENDED**. Aligned Part B with the companion doc's inverted decision — embedded GDScript capture script primary, MCP server optional (§2, §3, M0, M2). Designated the companion doc the prescriptive single source of truth (header). Audit artifact: `/tmp/depandabot-2026-06-17-poc-impl-guide-review.md`.
- **2026-06-17** — Added §7 "Agent operating contract" so a Claude Code run/workflow can execute the guide step-for-step: on-Mac precondition, per-milestone objective pass-signal + emitted artifact, judge-from-artifact rule, and workflow-shape guidance (single driver agent over multi-agent Workflow).
