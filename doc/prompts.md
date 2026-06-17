# Live Editing

OK

Please create a concise `agent-process.md` documenting the steps you've taken and your overall journey. Keep it brief, as I will use this to port the environment setup to another computer.


---

<details>
<summary>Archived</summary>

### [2026-06-17 15:50:52] Godot 4.6 PoC Self-Correction Loop

You are implementing a PoC for a Godot 4.6 / GDScript / 2D roguelike deckbuilder.
The PoC's ONLY product is a *proven self-correction loop* — not game content.

Read these two docs first, in this order — they are your spec:
1. doc/agent-development-loop.md   — prescriptive source: commands, the embedded
   GDScript capture script, headless gotchas, the two-part loop. (Single source
   of truth: if anything disagrees, this doc wins.)
2. doc/poc-implementation-guide.md — gates + guardrails. §7 is your operating
   contract (objective gate checks + what each milestone emits).

GOAL (Definition of Done, guide §1): on a deliberately broken change, a LOGIC bug
is caught at the test layer AND a VISUAL bug at the screenshot layer, both fixed,
slice ends green + visually correct. Demonstrate that once = success. Nothing more.

HOW TO RUN IT:
- Drive milestones M0 -> M4 as a single stateful loop with a todo list. After each
  gate, persist durable state to PLAN.md / STRUCTURE.md / MEMORY.md (companion §6b)
  so the run can resume. Use a multi-agent Workflow ONLY if you find genuine
  parallelism (guide §7); for a sequential pipeline a driver agent is the right tool.
- Treat each gate as the OBJECTIVE check in guide §7 — exit codes, a PNG on disk,
  the screenshot defect taxonomy + ASSERT PASS/FAIL. Judge from the artifact the
  step produced, never from "it compiled."
- VERIFY, DON'T GUESS: run commands and confirm. The companion doc's "Open Items"
  are hypotheses to test, not facts. When you confirm/correct something, update the
  companion doc and add a Changelog line (that's milestone M4).

NON-NEGOTIABLES (guide §2): GDScript not C#; 2D; Godot 4.6 idioms; game logic in
pure, GUI-free functions; both loop parts required before "done"; humans own
fun/balance — surface design questions, don't decide them.

ENVIRONMENT: run from the project root on this Mac, which has (or can install)
Godot 4.6 + a real display/GPU. START AT M0: verify the engine, gdUnit4, and the
capture script actually work. If a piece is missing, install it if you can; if it
needs something you can't do in-session (code signing, GPU), STOP and report —
do not mock around the thing the PoC is meant to prove (guide §6).

SCOPE FENCE (guide §5): one card, one tile, one rule, one loop. No real content,
art pipeline, hex map, economy, or exports. Build the proof, not the game.

First step: read both docs, then propose your M0 plan and the smallest slice y
use to close the loop — wait for my OK before executing past M0.

### [2026-06-17 15:36:42] Bevy vs. Godot 4.6 Comparison

**Context:** Roguelike, turn-based, deckbuilding 2D card game (hex overworld, fog of war). See [agent-development-loop.md](file:///Users/saiday/projects/game-design/doc/agent-development-loop.md).

**Goal:** Compare **Bevy** (Rust) and **Godot 4.6** (GDScript) and recommend the best choice based on the standard below.

**Ranked Standard:**
`agent-writability/observability > long-term scalability > open-source > fastest prototype`

**Key Questions to Address:**
- How does Rust/ECS vs. GDScript/Scene-tree affect agent readability, refactoring, and compilation?
- How easy is it to implement self-correction loops (headless testing, runtime screenshots, error observation) in both?
- Target platform compilation (desktop + mobile) complexity.

**Output Format:**
- Concise markdown comparison per standard.
- Clear recommendation with pros/cons.

### [2026-06-17 15:02:35] Extract Core Godot Agent Loop Scaffolding

**Context:** Refer to [agent-development-loop.md](file:///Users/saiday/projects/game-design/doc/agent-development-loop.md) (inspired by the proven `godogen` loop).
**Goal:** Extract a minimal, actionable guide of the core scaffolding setup and mechanics for this project.

**Constraints:**
- **Scaffolding Only:** Extract only the essential setup steps and execution loop mechanics (Part A & B).
- **Zero Explanations:** Exclude all rationale, engine comparisons, background details, and non-essential commentary.
- **Conciseness:** Keep bullet points straight to the point and action-oriented.
- **Max Length:** Strictly no more than 15 bullet points.

**Output Format:**
A concise list of up to 15 bullet points specifying the core scaffolding.

### [2026-06-17 13:47:51] Game Art PoC & Agent Pipeline Setup

create a game art poc guide, should focus on a principle-level guide that sets objectives, gates, and guardrails while leaving the how to the implementing agent.

art style will be decided later, there will be two art styles we will try to achieve: 1) painting 2) pixel. 
we will pick the better one later.

this PoC guide should focus on environments setup for agents creation pipeline, I do have a Mac studio with Apple M2 Ultra chip (96GB RAM) for local image generation tasks. 

This PoC is not a decisive doc, it is rather an exploration doc. proceed.

</details>