# ADRs (architecture decision records)

Decisions with lasting architectural consequences, recorded so future agents don't
re-litigate them. Read the ones touching your area before working; contradict one out loud
(in a new ADR or your report), never silently.

Convention (matches the existing files):

- Filename: sequential zero-padded number + kebab-case slug stating the decision as a
  declarative sentence, e.g. `0006-the-decision-as-a-statement.md`. Scan the directory for
  the highest number and increment.
- Body: an H1 restating the decision, then the reasoning as prose. Add a `## Consequences`
  section when the fallout isn't obvious from the decision itself. Cross-reference other
  records as `ADR-000N`.
- No dates, no status headers: ADRs describe current state; history lives in git commit
  messages.
- Scope split: a value or rule the game design leaves silent is a design-gap decision and
  goes in `insignificant-game/docs/decisions.md`; an ADR is for calls that shape the
  architecture. A big gap decision may appear in both.
