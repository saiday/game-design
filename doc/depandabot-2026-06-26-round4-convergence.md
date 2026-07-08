# depandabot audit — round-4 design convergence

> Subject: should we converge the round-4 game-design answers into the Obsidian planning corpus now?
> Reviewer: Codex (`codex:codex-rescue` subagent), second-opinion only. Date: 2026-06-26.
> Note: the design corpus lives in iCloud Obsidian (`agent plans/`); this audit is a process record kept in the build repo.

## §1 Current State

1. Round-4 human answers are recorded and locked in `questions-for-discussion.md` (lines 31–153): tax→`人口×稅率` (line 66); democracy unlocks at `文化>20` (line 46); the game is now a **5-fixed-opponent-civilization competition** with World Wars at rounds 15/35 (lines 35–40); happiness kept as a visible event-valve only (option B); combat redesigned as a **virtual battlefield** where cards become 部隊/設施 (lines 108–111); 工事卡 boundary = option A; 投誠 per-type thresholds, narrative-only, excluded from civ wars (line 131); operate lock-route = option A medium-strength (line 153).
2. Round-3's tax formula `人口×稅率×(幸福/100)` is now superseded; the `幸福/100` factor must be purged from `glossary.md`, `core-settings.md`, `converged-spine.md`, `candidate-options.md`, and `playable-concept.html`.
3. No `civilization-types.md` exists yet, though the design now depends on 5 rivals + World-War camp logic.
4. The run is permanent (no save-scumming, no reload); there is currently **no** described between-run meta-progression/unlock layer and no respec.
5. A parallel `round4-converge` workflow (run `wf_e4d6e607-3e0`) independently built the connected model + a foundational audit; its audit flags **enemy targeting / battlefield resolution** as a `blocker`.

## §2 Intended Goal

Should we proceed with converging the round-4 decisions into the corpus docs — updating glossary/core-settings/converged-spine/operation-options/battle-event-types/card-types/candidate-options/playable and creating `civilization-types.md` — with the operate lock-route encoded as medium-strength?

## §3 Current Plan

1. Rewrite tax to `人口×稅率` everywhere; purge every `幸福/100` reference.
2. Recast happiness as a visible event-valve (revolt threshold + democracy re-election); drop the tax-discount downstream.
3. Create `civilization-types.md`: 5 rivals (four-axis values + growth curve), World-War camp logic, reparations math, banner text.
4. Encode the virtual-battlefield combat model (cards→troops/facilities) in card-types/battle-event-types/core-settings.
5. Encode fort boundary (≤2–3 on field, destructible, one-shot block).
6. Encode 投誠 per-type relative thresholds, narrative-sensible only, excluded from civ wars.
7. Encode operate lock-route = medium (loses Legacy + exclusive ops, NOT unit cards) + raise per-era tradeoff density.
8. Encode democracy threshold `文化>20` + post-democracy multi-event exploration (2, +1 every 2 rounds, WW excepted) + candidate "action-description" cards (effects hidden; player infers).
9. Archive round-4; draft round-5 (incl. the human's preset readiness question + our 心戰 understanding to compare).
10. Update playable, index, memory, CLAUDE.md.

## §4 Missing Directional Confirmations

1. `risk` — Permanent run + medium-lock + **no** meta-progression/respec: a player can still strand on a dead operate-route. Is the free combat deck a sufficient escape hatch, or is a between-run unlock layer needed?
2. `unknown` — Normal-battle win/lose conditions on the virtual battlefield are undefined; enemy targeting / turn AI undefined. (Workflow audit: **blocker**.)
3. `unknown` — "Combat contribution" (splits World-War reparations 70%) has no defined source metric — an output with no input.
4. `assumption` — Ghost-civ growth = scripted/handicapped numbers, not a real 4X AI (to protect ≤3h pacing).
5. `risk` — Scope: 5 simulated civs + shared-table multiplayer World War + virtual-battlefield combat is a large jump from "operate-heavy, lightweight battle, ≤3h."
6. `assumption` — Candidate hidden-effect action-descriptions (player infers mapping) fit a half-idle democracy phase.

## §5 Evidence & Arguments

- Game Developer, *How to Power up Players with Upgrades* — recommends a respec option and avoiding builds the player can't recover from. **Dissent** vs the no-reload medium-lock lacking insurance. → §4.1 — https://www.gamedeveloper.com/design/how-to-power-up-players-with-upgrades
- Positech / Cliffski, *Unsure trade-offs in game design* — fuzzy, non-calculable tradeoffs are more engaging than transparent solvable ones; supports candidate hidden-effect descriptions and non-obvious lock personality. → §4.6 — https://www.positech.co.uk/cliffsblog/2012/03/07/unsure-trade-offs-in-game-design/
- Wikipedia, *Roguelike deck-building game* — permadeath frustration is mitigated by meta-progression / permanent unlocks; we currently lack that layer. **Dissent** vs "permanent run is fine as-is." → §4.1 — https://en.wikipedia.org/wiki/Roguelike_deck-building_game
- CivFanatics, *At what difficulty does the AI start cheating?* — 4X AI "growth" is yield/production handicap bonuses, not smarter play; supports modeling rivals as a handicapped growth curve, not real AI. → §4.4 — https://forums.civfanatics.com/threads/at-what-difficulty-level-does-the-ai-start-cheating.676651/

## §6 Second Opinion (Codex)

**Round 1 — Codex verdict: `AGREE`** (with three low-severity caveats; objection IDs assigned by reviewer):

- **O1** (conceptual, low) — Convergence must not imply the permanent-run medium-lock risk is resolved; keep §4.1 as an explicit round-5 risk.
- **O2** (conceptual, low) — Virtual-battlefield combat can be converged as *direction*, but its missing win/lose + enemy-AI rules (§4.2) must stay open round-5 questions, not be silently encoded.
- **O3** (implementation, low) — Document World-War reparations with a placeholder dependency on the undefined contribution metric (§4.3); don't present the 70% split as fully implementable.

**Claude response (all accept-and-amend):**
- re O1 → accept. Mark the medium-lock + no-meta-progression friction as a lead round-5 risk; do not present the lock-route as "safe."
- re O2 → accept, and **strengthen**: the parallel workflow audit independently rates this a **blocker**. Amendment: when converging, explicitly **retract** the old single-monster / enemy-HP combat language rather than leaving it to contradict the new model, and mark normal-battle resolution + enemy targeting as a **blocker-level round-5 root question** (`待定`), not a generic open item.
- re O3 → accept. Encode the reparations structure but tag the contribution metric `待定` → round-5.

No unresolved conceptual objection remains (Codex agrees with the goal; its caveats are pre-satisfied by the plan, with one accepted strengthening amendment on O2).

---

PROCEED_AMENDED
