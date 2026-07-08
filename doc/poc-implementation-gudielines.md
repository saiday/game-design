## Guidelines
- **Gameplay Mechanics:** Implement **everything** described in the design specs. Every major system (Operations, Map Node Selection, Battle Cards/Lanes, Economy/Debt, Eras/Rounds, and Democracy) must be fully simulated and playable to test and verify game balance.
- **Visuals & Audio:** Omit custom art and audio assets. Use the absolute minimum placeholder visuals (e.g., basic shapes, text, and default colors) required to make the game fully functional, playable, and testable. 
- **Extensibility:** Maintain a highly modular, decoupled code architecture so the PoC code can be directly extended for the final production game.
- **In-progress Documentation:** Continuously update and maintain documentation in the `poc-docs/` directory, detailing key architectural decisions, implementation choices, and design trade-offs made during development. Each key design decision deserves a standalone file.

---

## Software Architecture & Test-Driven Requirements
You must split all systems into clean Data/Logic and View layers.
1. **Pure logic separation (MANDATORY):** Game logic, state transitions, card calculations, map generation, difficulty multipliers, and battle outcomes must NOT be coupled to Godot scene nodes or `_ready` loops. Write them in pure scripts inheriting from `RefCounted` or as static utility classes.
2. **Static Typing:** Force static typing (`var x: int`, `func test() -> void`, etc.) on all GDScript variables and functions.
3. **Headless Unit Testing:** Set up `addons/gdUnit4` within `/Insignificant-game/`. You must write extensive unit tests under `test/` for all logic models:
   - **GameState & Economy:** Resource math, BP calculation, single-treasury operations, interest scaling, and debt threshold triggers.
   - **Difficulty Formulas:** Calculation of difficulty multipliers across eras and events.
   - **Operations & Costs:** Incremental building costs and region unlock thresholds.
   - **Battle Simulation:** Auto-battler attack priorities, damage resolution, fortification durability, and win/loss states.
   - **Card & Deck Rules:** Drawing, discarding, era-based unit evolution, and card deletion logic.
4. **Two-Part Verification Loop:**
   - **Part A:** Run headless gdUnit4 unit tests via `./addons/gdUnit4/runtest.sh` and ensure they exit 0.
   - **Part B:** Launch the scene runner to execute visual assertions (e.g. confirming labels/cards render within bounds) and capture a gameplay PNG in `captures/`.

---

## Difficulty System
- **Difficulty Formula:** Write a custom difficulty algorithm scaling:
  - Base enemy combat card scaling coefficients.
  - Severity and penalty outcomes of Opportunity Events.
  - Rival civ starting power and aggression parameters.
- **Documentation:** Create `/insignificant-game/doc/difficulty-design.md` detailing the formula. Also, copy this formula in `game-design/` corrsponding design docs.

---

## Verification Goals
1. All unit tests (`test/`) must run headlessly and pass successfully.
2. The scene runner must start, render the full UI blocks for each phase, successfully handle user clicks to simulate gameplay, and verify that the layout and fonts stay clean in generated screenshots.
