# phase3_scatter_topdown_batch.py — W14.8: the neutral field-scatter class (`scat_<type>_<prop>`).
#
# The last new class the top-down camera opened. Battle plates are BARE GROUND by ruling
# (phase3_backgrounds_topdown_batch.py's header: anything a unit could collide with is a separate
# object, never plate paint), so a top-down field with nothing on it but stations is a flat swatch
# with no scale reference. Scatter is what puts objects back on the ground without putting them back
# into the plate.
#
# WHAT IT IS ALLOWED TO BE (design/戰鬥.md §場景呈現, docs/decisions.md W14.8): DECORATION AND
# NOTHING ELSE. Scatter does not block, gives no cover, takes no damage, joins no layer of the
# 掩護鏈, and no rule may read it — 工事線 stays the single cover model. The view places it, seeded
# from the battle's own seed, avoiding the stations.
#
# That ruling constrains the ART, not just the code, and it is the one thing to hold onto when
# reading these cores: EVERY PROP IS LOW AND STEPPED-OVER. A boulder, a standing wall, a chest-high
# wire tangle would all be honest-looking obstacles, and a player who sees an obstacle and watches a
# unit shoot through it has been lied to by the art. So the vocabulary is deliberately flat and
# trodden — spilled, toppled, half-sunk, sawn-off, gathered — and no core names anything a person
# would have to walk around. Sandbags are the closest call in the set and ship as a COLLAPSED row
# for that reason.
#
# DERIVED PER BATTLE TYPE, which is the whole point. phase3_backgrounds_topdown_picks.json is the
# brief: each prop's material and palette words are lifted from the core that rendered its own
# approved plate, so the wheat field and the crater field scatter differently and a prop always
# looks like it came off the ground it is standing on. `PARENT` below imports those plate cores
# rather than restating them, so a plate re-roll shows up here instead of silently invalidating the
# scatter (--plan prints the parent core beside each prop for exactly that reason).
#
# THREE PROPS PER TYPE, 21 ids. Enough that a field can carry a handful without visible repetition,
# and each type gets one hard-edged object, one soft/organic one, and one flat ground mark — the
# three read differently at field size, where a scatter set that is all one silhouette family just
# looks like noise.
#
# NO FACING CLAUSE, unlike every other top-down class. A rock has no heading, so scatter is the one
# class the view may rotate freely for variety. That is only true if the light does not swing with
# the sprite, hence the even-overhead-light clause in the style tail — stated positively, because
# "no cast shadow" is a §8.3 rung-1 denial and denials summon what they deny.
#
# Usage (ComfyUI venv python, from assets/pipeline/):
#   phase3_scatter_topdown_batch.py            # every missing prop/seed, resumable
#   phase3_scatter_topdown_batch.py --plan
import argparse
import json
import os
import subprocess
import sys

from phase3_backgrounds_topdown_batch import PLATES as PARENT

SEEDS = [21, 22, 23, 24]
W = H = 1024
T2I = "workflows/krea2_lora_txt2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-scatter-topdown")
STATE = "phase3_scatter_topdown_state.json"

_FORM = "a simplified chunky shape with minimal surface detail"
# A GROUND MARK NEEDS THE OPPOSITE FORM CLAUSE FROM AN OBJECT, and the round-1 probe proved it
# rather than argued it. `scat_riot_scorch` asked for a flat black burn and came back as a ring of
# boulders around a white ash bed: the core says flat, `_FORM` says chunky, and the model resolved
# the contradiction by inventing something chunky to be. (The crater and the puddle survived the
# same clause because a raised rim IS chunky — which is why only the marks with no relief switch.)
# It also failed the decoration ruling in the header, since a boulder ring reads as an obstacle.
_FLAT_FORM = ("a simplified flat shape with minimal surface detail, lying flush with the ground "
              "with no height or relief")
_OVERHEAD = "steep high-angle view looking straight down from directly above"
_LIT = "lit evenly from straight above, flat even lighting across the whole object"
_ISO = "centered, isolated on a plain light gray background"

# THE OVERHEAD CLAUSE IS NOT ENOUGH FOR A SUBJECT WITH A CANONICAL SIDE PROFILE. Round 1 split
# cleanly along one line: every heap, spill and ground mark rendered genuinely overhead (craters,
# rubble, leaf drifts, puddles, duckboards, the scorch), and every SINGLE SOLID OBJECT reverted to a
# three-quarter product shot no matter how the camera was worded — a boulder in profile, a crate in
# perfect isometric, sandbags stacked in elevation, and a "fallen log" that came back as a standing
# tree trunk. The reason is that a rock or a crate has one silhouette the model knows it by, and
# from directly above it does not look like that silhouette; a heap has no canonical profile to
# lose, so it complies. Naming the TOP FACE as the subject's dominant feature is what converts it,
# which is also what the two cells that did work have in common (`tax_stump` and `worldwar_crater`
# are both read through a face turned at the camera).
_TOP = "its top surface turned toward the viewer and filling almost the whole of its outline"

# ROUND 2 MOVED NONE OF THE FIVE SOLID OBJECTS: `_TOP` bought a slightly flatter boulder and
# nothing else, and the "fallen log" stated as a bounded pair of sawn ends came back as a standing
# trunk with one end face at the bottom of the frame. So the camera clause itself is the suspect,
# not the amount of detail piled on top of it. `_OVERHEAD` is the UNIT class's wording, proven on
# figures, and a figure seen from above still looks like a figure; a prop has no such luck. The
# clause below is the BATTLE PLATE's wording instead, which is the phrasing already proven to pull
# GROUND subjects flat on this checkpoint, plus a register shift borrowed from the same finding:
# describe the sprite as the shape the object covers on the ground rather than as a prop portrait.
_ORTHO = ("photographed flat from straight above, orthographic, its outline drawn as the shape it "
          "covers on the ground")

# The props with no relief of their own, which take `_FLAT_FORM`. A prop earns a place here by
# failing as an object, not by looking flat in prose.
FLAT = {"scat_riot_scorch", "scat_riot_crate", "scat_hidden_vent"}

# The solid objects that need `_TOP` as well, all of them round-1 camera failures.
TOP = {"scat_field_rock", "scat_field_log", "scat_hidden_slab", "scat_hidden_stump",
       "scat_civwar_sandbags"}

# id -> (parent battle type, subject core). The core carries the parent plate's material and colour
# words; _TAIL carries camera, light and framing.
SCATTER = {
    # battle_tax — golden wheat stubble in crumbled dry brown tilled soil, loose straw
    "scat_tax_sheaf":   ("battle_tax", "a single toppled sheaf of cut golden wheat lying flat on "
                                       "its side, its stalks fanned loose and its binding still on"),
    "scat_tax_stones":  ("battle_tax", "a low spilled heap of rounded grey field stones cleared "
                                       "out of the soil, a few strays lying loose around it"),
    "scat_tax_stump":   ("battle_tax", "a low sawn-off tree stump of pale dry wood, its cut face "
                                       "turned upward, thick roots spreading flat into brown earth"),
    # battle_field — trampled green turf, worn bare patches, clover, thin pale dust
    "scat_field_rock":  ("battle_field", "a low broad grey boulder half sunk into the ground, its "
                                         "wide upper face worn smooth and flat, patches of green "
                                         "moss across it"),
    # Round 1 read "fallen log lying flat" as a standing tree trunk. The axis is stated as a bounded
    # pair of end points, which is the form that held 4/4 on the barrier cell where naming a run
    # tapered every wall it touched (cookbook §14).
    "scat_field_log":   ("battle_field", "a single fallen tree log lying flat on the ground, one "
                                         "round sawn end near the top of the frame and the other "
                                         "round sawn end near the bottom, split grey-brown bark "
                                         "along it and green moss on its upper side"),
    "scat_field_scrub": ("battle_field", "a low flat clump of green clover and coarse weeds "
                                         "spreading close to the ground, a few taller stems"),
    # battle_hidden — dark grey-green scorched ground, pale ash, faint green glow in the fissures
    "scat_hidden_slab":  ("battle_hidden", "a single broken flat slab of dark grey-green scorched "
                                           "stone lying part buried in the ground, its cracked "
                                           "upper face turned up, fine pale ash gathered along the "
                                           "edges where it meets the soil"),
    # Round 1 rendered molten orange lava in the crack: "fissure" plus "glow" plus scorched ground
    # is a volcanic prior, and the plate's own glow is cold pale green. The colour is now said twice
    # and cold is said outright, which is §8.3 rung 1 applied to a hue — occupy it, never deny it.
    "scat_hidden_vent":  ("battle_hidden", "a short jagged crack splitting dark grey-green scorched "
                                           "ground, fine pale ash banked along its lips, a cold "
                                           "pale green luminous light lying deep down inside the "
                                           "crack, cool green and grey throughout, its broken "
                                           "outline ragged and uneven all the way around"),
    # rewritten to mirror scat_tax_stump, the one stump that rendered genuinely overhead: the cut
    # face is the subject and the roots spread flat away from it
    "scat_hidden_stump": ("battle_hidden", "a low charred blackened tree stump sawn off close to "
                                           "the ground, its flat charred cut face turned upward, "
                                           "thick roots spreading flat away from it, fine pale ash "
                                           "gathered around them"),
    # battle_riot — grey granite cobbles, soot smudges, pale scattered ash
    "scat_riot_rubble": ("battle_riot", "a spill of prised-up grey granite cobblestones lying loose "
                                        "in a low scatter, the bare hollow they came out of beside "
                                        "them"),
    # "collapsed flat on its side" still left a box, and the model drew it intact in perfect
    # isometric — a standing crate, which is also the one silhouette this class must never have
    # (see the decoration ruling in the header). Round 2 leaves no box standing: the crate is a
    # spread of loose boards and nothing else.
    "scat_riot_crate":  ("battle_riot", "the smashed wreck of a wooden crate, its boards sprung "
                                        "apart and spread out loose and flat on the ground in a "
                                        "low scatter, their broken ends scorched brown"),
    # "burnt onto grey stone" named a stone object and got stone objects (see FLAT above). The
    # material the mark sits on is the PLATE's job — a scatter core never names its own ground.
    "scat_riot_scorch": ("battle_riot", "a black scorch mark burnt into the ground, a low bed of "
                                        "white ash and charred fragments lying in the middle of "
                                        "it, its edges fading out into soot smudges"),
    # battle_democracy — pale marble slabs, fine dark joints, drifted dead leaves
    "scat_democracy_drum":   ("battle_democracy", "a single toppled pale marble column drum lying "
                                                  "on its side, its fluting worn and one end chipped"),
    "scat_democracy_rubble": ("battle_democracy", "a low scatter of broken white marble chips and "
                                                  "slab fragments, their fresh faces bright and "
                                                  "their edges sharp"),
    "scat_democracy_leaves": ("battle_democracy", "a flat drift of dry dead brown leaves gathered "
                                                  "into a loose low pile, a few strays around it"),
    # battle_civwar — wet dark brown churned mud, standing rainwater, trodden straw
    # "a collapsed row" was rendered as a stack seen in elevation. Stacking is what forces a side
    # view, so round 2 says single layer outright and puts every bag on the ground.
    "scat_civwar_sandbags": ("battle_civwar", "about five muddy canvas sandbags lying flat on the "
                                              "ground side by side in one single loose layer, "
                                              "every bag resting directly on the mud and slumped "
                                              "half sunk into it, one split open and spilling wet "
                                              "sand"),
    "scat_civwar_puddle":   ("battle_civwar", "a wide shallow puddle of muddy brown standing "
                                              "rainwater lying flat in a hollow, its rim churned "
                                              "into soft dark mud"),
    "scat_civwar_planks":   ("battle_civwar", "a short run of broken duckboard planks lying flat "
                                              "and half pressed down into wet mud, trodden straw "
                                              "caught between them"),
    # battle_worldwar — shell craters in blackened soil, grey ash and rubble grit, dull red staining
    "scat_worldwar_crater": ("battle_worldwar", "a single small shell crater punched into blackened "
                                                "soil, a low ring of thrown-up grey ash and grit "
                                                "around its lip"),
    "scat_worldwar_debris": ("battle_worldwar", "a low scatter of twisted scorched metal fragments "
                                                "and torn shell splinters, rust brown and dull "
                                                "grey, part buried in ash"),
    "scat_worldwar_stump":  ("battle_worldwar", "a short blasted tree stump splintered off close to "
                                                "the ground, its raw wood pale against blackened "
                                                "bark, grey ash banked around it"),
}


def prompt_for(pid: str) -> str:
    form = _FLAT_FORM if pid in FLAT else _FORM
    camera = f"{_ORTHO}, {_TOP}" if pid in TOP else _OVERHEAD
    return f"{SCATTER[pid][1]}, {form}, game scenery prop sprite, {camera}, {_LIT}, {_ISO}"


def load_state() -> dict:
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(s: dict) -> None:
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(s, f, indent=1, ensure_ascii=False)
    os.replace(tmp, STATE)


def stem(pid: str, seed: int) -> str:
    return f"p3_td_{pid}_s{seed}"


def rendered(s: str) -> bool:
    return os.path.exists(f"{OUT}/{s}_00001_.png")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", action="store_true")
    ap.add_argument("--ids", help="comma-separated subset; a round that re-rolls only some props "
                                  "must name them, or the ones that already rendered well get "
                                  "re-rolled too")
    ap.add_argument("--types", help="comma-separated battle types, e.g. battle_riot,battle_civwar")
    ap.add_argument("--seeds", help="comma-separated seed override for a re-roll round (+100, §4)")
    args = ap.parse_args()

    ids = list(SCATTER)
    if args.types:
        want = set(args.types.split(","))
        unknown = want - set(PARENT)
        if unknown:
            raise SystemExit(f"unknown battle type(s): {sorted(unknown)}")
        ids = [p for p in ids if SCATTER[p][0] in want]
    if args.ids:
        ids = args.ids.split(",")
    seeds = [int(s) for s in args.seeds.split(",")] if args.seeds else SEEDS

    os.makedirs(OUT, exist_ok=True)
    state = load_state()
    todo = [(p, s) for p in ids for s in seeds if not rendered(stem(p, s))]
    print(f"{len(ids)} props x {len(seeds)} seeds; {len(todo)} to render "
          f"(~{len(todo) * 170 / 3600:.1f} h)", flush=True)
    if args.plan:
        for p, s in todo:
            print(f"  {stem(p, s)}\n     {prompt_for(p)}\n"
                  f"     parent {SCATTER[p][0]}: {PARENT[SCATTER[p][0]]}")
        return
    for i, (p, s) in enumerate(todo, 1):
        st = stem(p, s)
        cmd = [sys.executable, "comfy_run.py", T2I, "--seed", str(s), "--prompt", prompt_for(p),
               "--prefix", f"phase3-scatter-topdown/{st}",
               "--width", str(W), "--height", str(H), *LORA_ARGS]
        for attempt in (1, 2):
            print(f"--- [{i}/{len(todo)}] {st}" + (" (retry)" if attempt == 2 else ""), flush=True)
            if subprocess.run(cmd).returncode == 0:
                break
        else:
            raise SystemExit(f"{st} failed twice, aborting")
        state.setdefault(p, {})[str(s)] = {"stem": st, "seed": s, "prompt": prompt_for(p),
                                           "parent": SCATTER[p][0]}
        save_state(state)
    print(f"SCATTER SWEEP DONE: {len(todo)} rendered into {OUT}", flush=True)


if __name__ == "__main__":
    main()
