# phase3_cards_batch.py — Phase 3 class 3: card illustrations (cookbook §7), the 57-card scope
# in inventory.md "Card illustrations". Cards are txt2img DRAMATIC SCENE compositions (the Phase 1
# anchor style-refs/sb_r4_card_s42.png is a dense spear-phalanx battle scene, not an isolated
# sprite) — so this is a txt2img seed sweep like the backgrounds plates, NOT the units/buildings
# img2img era lineage. The frozen card frame composites OVER the illustration in Godot (style
# bible §9 content window); the illustration is a full rectangular scene, no keying (like
# backgrounds). Subject cores for the 52 unit/fort card forms are LIFTED from the already-approved
# unit manifest prompts (same subject, same era-appropriate objects the units class already made
# §8-clean) and reframed from "three identical figures isolated on gray" to a dramatic hero-forward
# scene; the 5 era-neutral skill cards are fresh conceptual subjects.
#
# PILOT-FIRST (cookbook discipline; Prompt 3 "cards go to review in smaller batches"): the pilot
# slice (infantry era1-6 + war_song + holes_dont_matter) validated the direction — human approved the
# dramatic-scene composition, chose "prefer clean seeds" as the signature countermeasure (the frame
# crop is the backstop, §14 2026-07-22), and picked seed 42 for the pilot (holes_dont_matter=43;
# see PICKS). All 57 subjects are now authored; the full sweep runs via mode `all` (resume-guarded,
# so the 24 pilot cells are not regenerated).
#
# Usage (ComfyUI venv python, from assets/pipeline/):
#   phase3_cards_batch.py one <id> <seed>     # single probe (style-carry check)
#   phase3_cards_batch.py pilot               # the pilot slice (PILOT ids) × SEEDS, resume-guarded
#   phase3_cards_batch.py all                 # every subject in CARDS × SEEDS (post-pilot full sweep)
#   phase3_cards_batch.py rerolls             # REROLLS × REROLL_SEEDS (post-pick fix round, resume-guarded)
#   phase3_cards_batch.py rerolls2            # REROLL2 × REROLL2_SEEDS (round-2 fix for 2 residual subjects)
#   phase3_cards_batch.py redo <id> <seed>    # re-roll one card with a new (bumped) seed
import json
import os
import subprocess
import sys

SEEDS = [41, 42, 43]                       # anchored on the proven Phase 1 card seed (s42)
W, H = 768, 1024                           # style bible §3 card size (portrait content window)
T2I = "workflows/krea2_lora_txt2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
# style bible §3 locked framing suffix for the card class. Backgrounds proved a bare landscape
# needs an explicit style-carrying tail (§14 2026-07-14); the `one` probe below verifies whether
# "game card illustration" already carries the Moebius look on figure subjects (units' "game unit
# sprite" suffix did). If the probe renders photoreal, extend this tail and log in cookbook §14 —
# the framing suffix is a working baseline, the recipe itself is locked.
SUFFIX = ", game card illustration, dramatic composition"
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-cards")
STATE = "phase3_card_state.json"

# id -> subject core (no suffix). Unit/fort forms reframed from the approved unit prompts:
# identity + era-appropriate objects preserved, isolation framing dropped, a lead figure forward
# with ranks behind in a battlefield setting for the "dramatic composition" the anchor establishes.
# §14 rules carried over from the units/backgrounds classes: no lettering on banners (occupy cloth
# with a plain colour or an emblem, never text); watch fake artist signatures (the card-specific
# §5 artifact class — the anchor itself has one bottom-right); positive slots only (never name a
# banned object).
CARDS = {
    # --- pilot: infantry (步兵團) era 1-6, cores from approved unit_infantry_* (era4 is the sprite
    # gap, written fresh as 線列步兵 musket line) ---
    "card_infantry_era1": "a tribal warrior in fur and hide charging forward swinging a heavy wooden club, red war-paint stripes on his arms, more club-warriors surging in a loose pack behind him, a windswept open steppe under a dramatic sky",
    "card_infantry_era2": "a spearman in a bronze helmet with a red horsehair crest leading a tight phalanx, round shields locked and long spears levelled forward, a plain crimson war banner raised behind them, a dramatic battlefield sky",
    "card_infantry_era3": "a foot soldier in chainmail and an open helmet raising his sword mid-stride, a pressing wall of shielded swordsmen behind him, dust and a dramatic overcast sky over a medieval battlefield",
    "card_infantry_era4": "a line-infantry soldier in a tall shako and a long buttoned coat levelling his musket with a fixed bayonet, a firing line of identically uniformed musketeers behind him, drifting powder smoke under a dramatic sky",
    "card_infantry_era5": "a soldier in an olive-drab uniform and a steel helmet advancing with his rifle raised, more helmeted riflemen pushing forward behind him, a war-torn field under a dramatic smoky sky",
    "card_infantry_era6": "a soldier in a bulky powered-armour suit with glowing infrared visor slits and oversized metal gauntlets striding forward, more armoured troopers advancing behind him, a futuristic battlefield under a dramatic sky",
    # --- archers (弓箭團, remote row) — era1/5/6 re-cut to the approved unit sprites: era1 is a
    # Y-forked slingshot held out horizontally (kept from reading as a bow), era5 a tube-scoped
    # bolt-action + brass spotting scope, era6 a boxy launcher with a round white sight disc (§14) ---
    "card_archers_era1": "a tribal slinger in a ragged hide tunic aiming a Y-shaped forked wooden slingshot held out at arm's length, its two stretched leather bands pulled back to a small pouch at his cheek, round stones in a belt pouch, more slingers behind him, red feathers in their hair, a dramatic steppe sky",
    "card_archers_era2": "an archer in a green tunic drawing a tall wooden longbow to full draw, a rank of longbowmen loosing red-fletched arrows behind him, a dramatic battlefield sky",
    "card_archers_era3": "a crossbowman in a padded jacket and iron kettle helmet leveling a heavy crossbow, more crossbowmen behind him, red-fletched bolts at their belts, a dramatic overcast battle sky",
    "card_archers_era4": "a skirmisher in a soft black peaked cap firing his musket, a loose line of musket skirmishers behind him, drifting powder smoke, a dramatic sky",
    "card_archers_era5": "a sniper in a hooded leaf-camouflage cloak kneeling and aiming a bolt-action rifle with a long black tube telescopic sight and a folding bipod under the barrel, a spotter crouched beside him peering through a yellow brass spotting scope on a monopod, a tense dramatic battlefield",
    "card_archers_era6": "a soldier in a gray military uniform and a steel helmet shouldering a boxy tube missile launcher with a large round white optical sight disc on its side and a thin antenna on top, a teammate carrying a folded green radar dish on a tripod frame on his back, a futuristic battlefield under a dramatic sky",
    # --- cavalry (騎兵團, melee mobile; late eras are tanks) ---
    "card_cavalry_era1": "a tribal rider in furs charging on a shaggy horned beast with a red cloth harness, more beast-riders thundering behind him, a dramatic steppe sky",
    "card_cavalry_era2": "a wooden war chariot pulled by two galloping horses, a driver and a spearman aboard, a plain red pennant streaming from the rail, dust and a dramatic battle sky",
    "card_cavalry_era3": "an armored knight in a plain steel helm couching a raised lance at the charge, his horse in a red caparison and a smooth steel face plate, a wedge of knights behind, a dramatic sky",
    "card_cavalry_era4": "a dragoon in a brass comb-crested helmet with a black horsehair mane galloping and firing a short flintlock carbine, a green coat with red cuffs, more dragoons charging behind, a dramatic sky",
    "card_cavalry_era5": "a heavy battle tank with riveted armor advancing with its long cannon leveled, more tanks looming behind through drifting smoke, a dramatic war sky",
    "card_cavalry_era6": "a sleek unmanned tracked combat vehicle with a sensor dome rolling forward low over churned ground, its tracks biting into the dirt and kicking up dust, a column of more unmanned tanks rolling on the ground behind it with their tracks in the dirt, a plain unmarked gunmetal hull of fine panel seams, a futuristic battlefield sky",
    # --- engineers (工兵團, melee support) ---
    "card_engineers_era1": "a tribal laborer in a hide tunic hefting a heavy log beam and a stone hammer, coils of rope over his shoulders, a red headband, more laborers working behind him, a dramatic sky",
    "card_engineers_era2": "a builder in a leather apron swinging a great wooden mallet, others laying stone blocks and carrying a beam with a red cloth strip tied at its end, a dramatic construction sky",
    "card_engineers_era3": "a sapper in an iron kettle helmet and a leather jerkin pushing a tall wheeled wooden plank shield, others carrying a pickaxe and a bundle of sticks, plain red shoulder sashes, a dramatic siege sky",
    "card_engineers_era4": "a soldier in a gray uniform with red collar trim carrying a wooden plank bridge section tucked under one arm, others shouldering a shovel and a coil of wire, a dramatic battlefield sky",
    "card_engineers_era5": "a yellow armored engineering vehicle with a bulldozer blade and a crane arm plowing forward, soldiers in olive uniforms and steel helmets riding in it, a dramatic war-torn sky",
    "card_engineers_era6": "a soldier in a powered exo-frame suit with hydraulic arms hauling a folded bridge girder, another wielding a heavy cutting torch with a glowing orange tip, a futuristic battlefield sky",
    # --- elite_forces (菁英特種部隊, melee elite) ---
    "card_elite_forces_era2": "a royal guard in gilded bronze armor and a tall red-plumed helmet leveling an ornate halberd, a purple cloak, a rank of guards behind him, a dramatic sky",
    "card_elite_forces_era3": "a temple knight in a white surcoat over chainmail raising a greatsword, a single golden tree emblem on the surcoat, more knights behind him, a dramatic sky",
    "card_elite_forces_era4": "a grenadier in a dark blue coat hurling a round grenade with a sputtering fuse, a musket slung across his back, more grenadiers behind him, drifting smoke, a dramatic sky",
    "card_elite_forces_era5": "a commando in black tactical armor and green-lensed night-vision goggles advancing with a compact rifle, his team stacked close behind him, a tense dramatic night battlefield",
    "card_elite_forces_era6": "a cyborg super-soldier with sleek chrome cybernetic limbs and glowing blue eye implants striding forward gripping a heavy rifle, more cyborg soldiers behind him, a futuristic battlefield under a dramatic sky",
    # --- artillery (火砲, remote siege) ---
    "card_artillery_era3": "a squat bronze bombard cannon on a timber sled firing skyward in a burst of smoke, a crewman brandishing a glowing linstock, stone cannonballs stacked beside it, a dramatic siege sky",
    "card_artillery_era4": "a field cannon with a bronze barrel on a spoked-wheel carriage firing, gunners in dark blue uniforms ramming and aiming, a pyramid of iron cannonballs, drifting smoke under a dramatic sky",
    "card_artillery_era5": "a tracked self-propelled howitzer in olive drab firing its long elevated barrel with a great muzzle flash, crew working at the hull, a dramatic battlefield sky",
    "card_artillery_era6": "a futuristic tracked railgun platform firing a searing projectile along its twin parallel magnetic rails, matte gunmetal armor of fine panel seams, drifting smoke and a dramatic overcast sky over a battlefield",
    # --- bomber (轟炸機, air) — plain unmarked hulls (no real-world national markings, lore) ---
    "card_bomber_era4": "a long silver-gray rigid airship droning low over a battlefield, small bombs falling from its gondola, searchlight beams crossing a dramatic night sky, a plain unmarked hull",
    "card_bomber_era5": "a heavy four-engine propeller bomber banking through a flak-filled sky, its bomb bay open with bombs falling, a plain olive-drab unmarked fuselage, a dramatic cloudscape",
    "card_bomber_era6": "a black angular flying-wing stealth bomber cutting across a dramatic dusk sky, its bomb bay open with a single guided bomb dropping, matte-black unmarked surfaces",
    # --- holy_warriors (聖戰士團, 國策限定, era 4 only) ---
    "card_holy_warriors_era4": "a musketeer in a white coat holding his musket upright against his shoulder, a single golden tree emblem on his chest, a rank of white-coated musketeers behind him, a dramatic sky",
    # --- privateers (私掠傭兵團, 國策限定) ---
    "card_privateers_era3": "a bandit in a dark leather jerkin brandishing a short curved sword, a closed brown loot sack over his shoulder, a rough band of raiders behind him, a dramatic frontier sky",
    "card_privateers_era4": "a thief in a dark hooded coat and neck scarf clutching a brass-cornered suitcase under his arm, glancing back over his shoulder, a shadowy street opening to a dramatic sky",
    "card_privateers_era5": "a cyber hacker in a suit walking with an open laptop, its lid a plain unmarked metallic surface, cascading data-light around him and a dramatic city-night sky behind",
    # --- shield_wall (盾陣, fortification; blocks melee) — the wall manned in action ---
    "card_shield_wall_era1": "a standing wall of tall rough wooden plank shields lashed with rope, spear tips poking over the top, warriors braced behind it, red cloth strips at the joints, a dramatic battle sky",
    "card_shield_wall_era2": "a tight wall of overlapping kite shields each embossed with a plain raised ring, warriors locked shoulder to shoulder behind it, a dramatic battle sky",
    "card_shield_wall_era3": "a stone battlement wall with crenellations and arrow slits, defenders manning the parapet, a dramatic besieged sky",
    "card_shield_wall_era4": "a chest-high wall of stacked burlap sandbags with wooden support posts, soldiers hunkered down behind it, drifting smoke and a dramatic war sky",
    "card_shield_wall_era5": "a tall fence of taut electrified steel wire mesh on low concrete blocks, white ceramic insulators on the dark posts, sparks arcing along it, a dramatic dusk battlefield",
    "card_shield_wall_era6": "a modular barrier wall of smooth matte-gray polymer panels bolted to a steel frame with deployable struts at its base, troops sheltering behind it, a futuristic battlefield sky",
    # --- anti_air (防空飛彈, fortification; blocks ranged/air) — the emplacement firing skyward ---
    "card_anti_air_era1": "a slanted hide-roofed timber arrow shelter, warriors crouched beneath it as arrows thud into the raw hides overhead, a windswept battlefield under a dramatic sky",
    "card_anti_air_era2": "a tall timber arrow tower with a roofed shooting platform and wooden hoardings, defenders loosing arrows from it, a plain red cloth strip at a corner post, a dramatic battle sky",
    "card_anti_air_era3": "a round stone defense tower with machicolations, a crew working a skyward-aimed ballista on its open top, dramatic clouds over a besieged wall",
    "card_anti_air_era4": "an anti-aircraft flak cannon with a long barrel angled skyward firing, a crew feeding shells, plain olive-drab paint, tracer streaks across a dramatic smoky sky",
    "card_anti_air_era5": "a tracked missile vehicle in olive drab launching a white surface-to-air missile skyward on a trail of smoke, a dramatic dusk battlefield sky",
    "card_anti_air_era6": "a boxy laser interception turret on a gimbal mount firing a brilliant beam skyward through its optical aperture, matte olive-drab housing, a futuristic battlefield under a dramatic sky",
    # --- skill cards (era-neutral conceptual subjects) ---
    # 軍歌: two-turn +1 attack morale buff -> a martial anthem / morale surge.
    "card_war_song": "ranks of soldiers marching shoulder to shoulder singing with mouths open and fists raised, one of them blowing a great brass war horn, plain crimson banners without any lettering held high, a triumphant dramatic sky",
    # 這些破洞不影響功能: the joke card (out-turn card-cost -1) -> battered gear that "still works".
    "card_holes_dont_matter": "a grinning ragged soldier proudly holding up a battle-tattered shield riddled with holes, his patched dented armour full of gaps, a confident carefree shrug, a dramatic battlefield sky behind him",
    # 爛仗時候才宣揚愛與和平: rock-spirit Legacy card (destroy a non-boss enemy after battle round 5)
    # -> ironic countercultural peace gesture amid war.
    "card_love_and_peace": "a defiant long-haired figure raising a two-finger peace sign, standing in a war-torn urban city street of shattered concrete buildings and rubble, plain banners without any lettering, a dramatic overcast sky",
    # 勸降廣播: culture-export policy card (flip a weak enemy unit) -> a battlefield surrender broadcast.
    "card_persuasion_broadcast": "a military loudspeaker truck with a tall broadcast horn array mounted on its roof and a plain unmarked canvas canopy, parked on a grassy riverbank beside a wide calm river, distant enemy troops across the water lowering their weapons, a dramatic sky",
    # 軌道打擊: space-station policy card (destroy a non-boss enemy) -> a strike from orbit.
    "card_orbital_strike": "a high orbital bird's-eye view looking down at the curved blue earth far below, a satellite in the foreground firing a thin brilliant energy beam down toward the planet surface, a small burst of light where the beam strikes, a star-field of deep space around, a dramatic cosmic scene",
}

# Pilot slice (mode `pilot`) — the 8 subjects run to validate the direction. mode `all` runs CARDS.
PILOT = [
    "card_infantry_era1", "card_infantry_era2", "card_infantry_era3",
    "card_infantry_era4", "card_infantry_era5", "card_infantry_era6",
    "card_war_song", "card_holes_dont_matter",
]

# Human full pick pass over the 12 per-line contact sheets (2026-07-22): one seed per subject.
# Supersedes the pilot picks (war_song 42->41, infantry era2/era4 42->41). Consumed by the future
# phase3_cards_freeze.py. 49 subjects are picked here; the 8 in REROLLS were sent back for a new
# round (below) and get their picks appended once the human picks the re-rolled seeds.
PICKS = {
    "card_infantry_era1": 42, "card_infantry_era2": 41, "card_infantry_era3": 42,
    "card_infantry_era4": 41, "card_infantry_era5": 42, "card_infantry_era6": 42,
    "card_archers_era2": 42, "card_archers_era3": 42, "card_archers_era4": 41,
    "card_cavalry_era1": 43, "card_cavalry_era2": 43, "card_cavalry_era3": 43,
    "card_cavalry_era4": 43, "card_cavalry_era5": 43,
    "card_engineers_era1": 41, "card_engineers_era2": 41, "card_engineers_era3": 42,
    "card_engineers_era4": 41, "card_engineers_era5": 42, "card_engineers_era6": 42,
    "card_elite_forces_era2": 42, "card_elite_forces_era3": 42, "card_elite_forces_era4": 42,
    "card_elite_forces_era5": 43, "card_elite_forces_era6": 42,
    "card_artillery_era3": 41, "card_artillery_era4": 41, "card_artillery_era5": 41,
    "card_bomber_era4": 42, "card_bomber_era5": 42, "card_bomber_era6": 42,
    "card_holy_warriors_era4": 43,
    "card_privateers_era3": 42, "card_privateers_era4": 43, "card_privateers_era5": 41,
    "card_shield_wall_era1": 41, "card_shield_wall_era2": 41, "card_shield_wall_era3": 42,
    "card_shield_wall_era4": 41, "card_shield_wall_era5": 41, "card_shield_wall_era6": 43,
    "card_anti_air_era1": 43, "card_anti_air_era2": 41, "card_anti_air_era3": 42,
    "card_anti_air_era4": 42, "card_anti_air_era5": 42, "card_anti_air_era6": 43,
    "card_war_song": 41, "card_holes_dont_matter": 43,
    # re-roll picks (2026-07-23, from phase3_cards_rerolls.png): cavalry_era6 + persuasion_broadcast
    # picked from their round-2 seeds (47-49), the other six from round-1 (44-46). Now 57/57 picked.
    "card_archers_era1": 45, "card_archers_era5": 46, "card_archers_era6": 46,
    "card_cavalry_era6": 48, "card_artillery_era6": 44,
    "card_love_and_peace": 45, "card_persuasion_broadcast": 47, "card_orbital_strike": 45,
}

# Re-roll round (2026-07-22): subjects the human sent back with a fix, re-cut in CARDS above and
# regenerated on fresh seeds so the originals (41-43) stay for reference. Human notes:
#   archers_era1  -> slingshot was reading as a bow; re-cut to the Y-forked sprite
#   archers_era5  -> scope/sight didn't match the unit sprite; re-cut to tube scope + brass spotter
#   archers_era6  -> launcher sight didn't match the unit sprite; re-cut to the round sight disc
#   cavalry_era6  -> drone tank was floating; grounded on churned dirt
#   artillery_era6-> sky read as thunder/lightning; overcast + smoke instead
#   love_and_peace-> drop the flower; background is an urban city street
#   persuasion_broadcast -> nothing emanating from the horns; background is a riverside
#   orbital_strike-> top-down orbital bird's-eye view with the earth and a satellite
REROLL_SEEDS = [44, 45, 46]
REROLLS = [
    "card_archers_era1", "card_archers_era5", "card_archers_era6",
    "card_cavalry_era6", "card_artillery_era6",
    "card_love_and_peace", "card_persuasion_broadcast", "card_orbital_strike",
]

# Round-2 fix (2026-07-23): two subjects whose round-1 re-cut left a residual defect, re-cut again
# on seeds 47-49. cavalry_era6: the "swarm of drone tanks" backdrop still floated -> a ground column;
# persuasion_broadcast: "plain banners" pulled in national flags + canopy emblems -> banners dropped,
# an explicit plain unmarked canopy. Round-1 cells (44-46) stay on disk for reference.
REROLL2_SEEDS = [47, 48, 49]
REROLL2 = ["card_cavalry_era6", "card_persuasion_broadcast"]


def load_state() -> dict:
    if os.path.exists(STATE):
        with open(STATE) as f:
            return json.load(f)
    return {}


def save_state(state: dict) -> None:
    with open(STATE, "w") as f:
        json.dump(state, f, indent=1, ensure_ascii=False)


def run(stem: str, cmd: list[str]) -> None:
    for attempt in (1, 2):
        print(f"=== {stem}" + (" (retry)" if attempt == 2 else ""), flush=True)
        if subprocess.run(cmd).returncode == 0:
            return
    raise SystemExit(f"{stem} failed twice, aborting the batch")


def gen_card(state: dict, card_id: str, seed: int, resume: bool = False) -> None:
    core = CARDS[card_id]
    stem = f"p3_card_{card_id[len('card_'):]}_s{seed}"
    if resume and os.path.exists(f"{OUT}/{stem}_00001_.png"):
        print(f"=== {stem} (exists, skipped)", flush=True)
        return
    prompt = core + SUFFIX
    run(stem, [sys.executable, "comfy_run.py", T2I,
               "--seed", str(seed), "--prompt", prompt,
               "--width", str(W), "--height", str(H),
               "--prefix", f"phase3-cards/{stem}", *LORA_ARGS])
    state.setdefault(card_id, {})[str(seed)] = {"stem": stem, "seed": seed, "prompt": prompt}
    save_state(state)


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "pilot"
    state = load_state()
    if mode == "one":
        gen_card(state, sys.argv[2], int(sys.argv[3]))
    elif mode == "redo":
        gen_card(state, sys.argv[2], int(sys.argv[3]))
    elif mode == "rerolls":
        for card_id in REROLLS:
            for seed in REROLL_SEEDS:
                gen_card(state, card_id, seed, resume=True)
    elif mode == "rerolls2":
        for card_id in REROLL2:
            for seed in REROLL2_SEEDS:
                gen_card(state, card_id, seed, resume=True)
    elif mode in ("pilot", "all"):
        ids = PILOT if mode == "pilot" else list(CARDS)
        for card_id in ids:
            for seed in SEEDS:
                gen_card(state, card_id, seed, resume=True)
    else:
        raise SystemExit(f"unknown mode {mode}")
    print("BATCH_DONE", flush=True)


if __name__ == "__main__":
    main()
