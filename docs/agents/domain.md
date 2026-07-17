# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

**This repo has no `CONTEXT.md`, deliberately.** Its glossary already lives in
`insignificant-game/doc/architecture.md` ("Glossary (design term → code name)"), and
`insignificant-game/CLAUDE.md` directs every agent to read that file first. A second glossary at
the root would give the project two places defining its vocabulary, which is the exact failure
that produced a phantom 手牌 mechanic (see `docs/adr/0001-money-is-the-only-deployment-gate.md`).
Add terms there, not here.

- **`insignificant-game/doc/architecture.md`** — the contract and the glossary. Read before coding.
- **Game rules and design content** — the Obsidian corpus (upstream truth), snapshotted read-only
  into `insignificant-game/design/`. Each doc's `code:` frontmatter maps it to its module.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in. Architectural decisions
  with system-wide reach live here; game-rule content does not.

If a file named above doesn't exist, **proceed silently**. Don't flag its absence; don't suggest
creating it upfront. The `/domain-modeling` skill creates docs lazily, when terms or decisions
actually get resolved.

## File structure

Single-context repo (most repos):

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

Multi-context repo (presence of `CONTEXT-MAP.md` at the root):

```
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← system-wide decisions
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  ← context-specific decisions
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because…_
