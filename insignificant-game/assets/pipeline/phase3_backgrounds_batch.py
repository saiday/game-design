# phase3_backgrounds_batch.py — Phase 3 class 4: background plates (cookbook §7), the 17-plate
# scope in inventory.md Backgrounds (three-scene model: style bible §11, corpus 場景呈現 sections).
# City era plates are an img2img lineage like buildings (one seed = one coherent 6-era valley;
# era-gated per the §14 propagation rule); every other plate is txt2img. Landscape subjects
# REQUIRE the style-carrying suffix (§14) or they render photoreal; map subjects swap the view
# tail. Plates carry an EMPTY middle ground: city sprites / unit sprites composite there in
# engine, the plate never draws them. Usage (ComfyUI venv python, from assets/pipeline/):
#   phase3_backgrounds_batch.py plates                    # all txt2img plates (city era 1 + 11 others) × seeds
#   phase3_backgrounds_batch.py city_era <n>              # img2img wave: era n from each chain's era n-1
#   phase3_backgrounds_batch.py city_era <n> --redo chain:seed   # re-roll listed city cells
#   phase3_backgrounds_batch.py redo <plate_id> <seed>    # re-roll one txt2img plate with a new seed
import json
import os
import subprocess
import sys

SEEDS = [51, 52, 53]
W, H = 1920, 1088
# Lower than buildings' 0.55: the empty parent must constrain invented content. Env override
# (P3BG_DENOISE) exists for per-cell re-rolls where a clean parent's composition keeps pulling
# inventions at 0.5 (chain 51 era 4 drew a farmstead twice; 0.42 hugs the parent tighter).
DENOISE = float(os.environ.get("P3BG_DENOISE", "0.5"))
T2I = "workflows/krea2_lora_txt2img.json"
I2I = "workflows/krea2_lora_img2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
STYLE = ", hand-painted game background art, watercolor and ink illustration, soft flat colors, clean line work, wide panoramic side view"
MAPSTYLE = ", hand-painted game map art, watercolor and ink illustration, soft flat colors, clean line work, top-down view"
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-backgrounds")
STATE = "phase3_background_chains.json"

# City era plates (bg_city_era1..6): the SAME valley across all six eras — only the land
# develops, and the middle ground stays an empty meadow for the composited city strip
# (time-of-day is an engine grade so every plate is day-lit). No buildings in the plate
# (they are the sprites class). Farm plots are BANNED from these subjects: tilled/terraced
# soil pulls invented farmsteads out of the img2img lineage (era-2: 3/3 dirty on the first
# roll, 3/3 STILL dirty after "uninhabited" phrasing — the soil texture implies residents
# harder than words deny them). Era development reads through infrastructure instead:
# footpaths -> hedgerow lanes -> earth road -> paved road -> sleek parkland, with the
# bridge upgrading alongside.
CITY = {
    # era-1 v2: both v1 roots (s51, s71) drew formed paths/roads across the open flanks (s71
    # added a distant smoke plume) — the style's valley prior fills empty flanks with winding
    # roads. Occupy the flanks with unbroken grass; a path-free era 1 is load-bearing because
    # era-2's footpaths must read as the first infrastructure of the ladder.
    # era-1 v3: v2 rolled an outlined falling-blob cascade from the sky's top edge 2/2 (s72,
    # s78 — petal/scrap shapes, some glyph-like). v2 had added "unbroken drifts of tall wild
    # grass" next to the v1-proven "drifting clouds"; the doubled drift token reads as things
    # adrift in the air. De-drift the flank clause, keep everything else.
    # era-1 v4: v3 (s84) still sprayed an ink-speck debris cascade flaking off the cloud
    # outlines in two sky regions — weaker than s72/s78 but same class, and a root defect
    # propagates into every i2i descendant. Chains 52/53 passed with "drifting clouds", but
    # this root has now rejected 4x across two wordings and the specks always trail from
    # cloud edges. Remove the carrier: no clouds. Eras 2-6 never name clouds, so nothing
    # downstream depends on them.
    1: "a vast untamed grassland valley, unbroken tall wild grass and wildflower meadows covering the far flanks, scattered ancient trees, a thin winding river, a wide flat empty meadow across the middle ground, distant blue mountain ranges, a clear soft morning sky",
    # era-2 v2 (chain 51 rebuild): s96 grew a covered wagon + trailer on the "empty meadow"
    # and a valley-spanning embankment band at the unpinned distance boundary. Port the two
    # occupiers era-5 v5 proved: "completely deserted" for the meadow, an unbroken wild
    # forest treeline for the distance band. Era markers unchanged. Chains 52/53 era-2
    # cells stay on the v1 wording they passed with.
    # era-2 re-roll s121+ (chain 51): s103 passed §8 itself but breeds era-3 occupants —
    # that cell went 0/5 across three wordings (v1/v2/v3) and two denoises (0.5, 0.42),
    # while chains 52/53 passed era-3 v1 immediately from their own parents, isolating
    # the parent composition as the causal variable. Retire s103, draw a fresh era-2
    # composition from the s89 root on unchanged v2 wording and default denoise.
    # (s121 confirmed the cleaner-composition thesis but rejected on first-occurrence
    # seed noise: a dotted speck-chain seam down the sky — the era-1 cascade class — and
    # a jar-shaped whimsy object in a foreground flower center. Seed bumps continue.)
    2: "a vast uninhabited grassland valley, thin dirt footpaths and split-rail fences on the far flanks, a wooden footbridge over the thin winding river, a wide flat completely deserted meadow across the middle ground, an unbroken dense wild forest treeline beyond, distant blue mountain ranges, soft morning sky",
    # era-3 v2 (chain 51 rebuild): chains 52/53 passed v1, but chain 51 is 0/2 and both
    # rolls put something ON the "empty meadow" (s106 a tiny red livestock/shed mole, s109
    # a seated hooded figure with a bundle) — 2/2 says the meadow slot, so port the proven
    # "completely deserted" pin. s109's lane walker and cloud speck cascade were first
    # occurrences (seed noise). Chains 52/53 era-3 cells keep their locked v1 renders.
    # era-3 v3 (chain 51): "completely deserted" pins AGAINST occupants but leaves the
    # surface itself unnamed, and the slot kept generating (s115 @0.42 grew a red-brown
    # mound mid-meadow — third meadow occupant across wordings after s106/s109). Occupy
    # the surface in benign form: a meadow OF plain unbroken short grass. s115's orange
    # boot whimsy object on the lane verge was a first occurrence (seed noise); its era
    # markers (orchard rows, hedgerow lanes, capped-pillar footbridge) all landed at 0.42.
    # era-3 v3 outcome (chain 51): s118 still populated the bands (arched-window burrow
    # dwelling in the hedge mound — second built structure there after s106's gate-shrine —
    # plus creature blobs, a teardrop-creature pair and a sail-shaped whimsy object on the
    # meadow). 0/5 for this cell while chains 52/53 passed era-3 v1 first-roll from their
    # own parents: the s103 PARENT breeds the occupants, wording is exhausted. Escalation:
    # re-roll era-2 (retire s103), then retry era-3 from the new parent on this v3 wording.
    # era-3 v4 (chain 51, from the s122 parent): v3's meadow pin holds (clean on s123/s124)
    # but the lane-end horizon band built habitation 2/2 (s123 farmhouse pair, s125 red hut
    # with lit window) — lanes imply a destination exactly like era-5's road did, and era-3
    # is the only era wording WITHOUT the treeline occupier. Port the proven pin ("unbroken
    # dense wild forest treeline beyond") onto the vanishing band. Seed-noise one-offs, not
    # wording: s123 bridge props + hedge-base creature pair, s124 signature-glyph on the
    # fence rail (title-plate corner class, next lever if it recurs), s125 path walker +
    # flowering tree on the meadow.
    # era-3 @0.42 (chain 51): v4's treeline pin got under-flown — s126 raised gold citadel
    # towers ABOVE the treeline (horizon habitation 3/4: farmhouse, hut, citadel) and put a
    # full cottage on the near-left flank. Wording can't pin the sky band; s123-s126 all
    # ran at the 0.5 driver default while 0.42 is the proven era-transition leash and s115
    # proved era-3's markers (orchards, lanes, footbridge) land at 0.42. Wording stays v4;
    # the leash drops to P3BG_DENOISE=0.42 like every other chain-51 transition.
    # era-3 v5 (chain 51): 0.42 held every band EXCEPT the lane vanishing points — s127
    # nested two pavilion huts exactly where the lanes meet the treeline (habitation 4/5
    # from this parent: farmhouse, hut, cottage+citadel, two pavilions). The treeline pin
    # covers the band BEHIND the lane ends, not the ends themselves; lanes demand a
    # destination like era-5's road did. Name the slot's desire in benign form: each lane
    # ends at a plain wooden field gate (rural-gate class, benign per the adjudication
    # line). s127's blue slab was blunt/panel-less (note-only), road blob ambiguous.
    3: "a vast uninhabited green valley, hedgerow-lined lanes ending at plain wooden field gates, neat rows of planted young trees on the far flanks, a stone footbridge over the winding river, a wide flat completely deserted meadow of plain unbroken short grass across the middle ground, an unbroken dense wild forest treeline beyond, distant blue mountain ranges, soft morning sky",
    # era-4 v2 (chain 51 rebuild; chains 52/53 keep their locked v1 renders): s130 put two
    # grazing white horses ON the "empty meadow" — this chain's meadow slot has bred an
    # occupant in every era that lacked the full pin (wagon s96, mole s106, figure s109,
    # mound s115, horses s130), so port the proven era-3 v3 surface pin. s129's outlined
    # sky circles (balloon class) were a first occurrence, handled by the seed bump.
    # era-4 v3 (chain 51): v2's meadow pin was overrun — s131 laid a camel-like herd plus
    # creature mounds ON the pinned meadow, wrecked fence debris beside it, floated pink
    # balloons up the mountain (floater class 2/3 from this parent) and built horizon
    # habitation twice (windowed wall-band, red-roof hamlet). Band-by-band fixes: fences
    # bind to the road ("lined with") because "fences on the far flanks" + the s128
    # parent's inherited gates reads as PADDOCKS and paddocks demand livestock; the proven
    # treeline pin ports in against the horizon builders; "hazy" (the only atmospheric-
    # particle token in any era wording) leaves in favor of a clear pale sky since both
    # floater rolls carried it. Meadow pin stays. Denoise stays 0.42.
    # era-4 v4 (chain 51): v3 held its own fixes (no debris, no floaters, clean horizon)
    # but livestock grazed the PINNED meadow again on s134 (orange horse + pink foal +
    # pale horse) — 3/5 same class from this parent, overriding the surface pin. The
    # carrier is "cart ruts": ruts imply the horses that cut them, and the s128 parent's
    # field gates already read as paddocks. The road itself is the era marker, so the
    # ruts token leaves. s134 also grew a bottle-shaped lantern + twin striped posts at
    # the bridge approach; that slot gets the era-5 v6 pillar filler chain 51's own s128
    # drew and passed with. s132/s133 rejects were one-off classes (pink arch stone +
    # slab pair + eye-rock + glow cluster; star + heart doodles) handled by seed bumps.
    4: "a vast uninhabited valley, a packed earth road lined with long wooden fences, a stone arch bridge over the river, low capped stone pillars at the bridge ends, a wide flat completely deserted meadow of plain unbroken short grass across the middle ground, an unbroken dense wild forest treeline beyond, distant blue mountains under a clear pale sky",
    # eras 5-6 originally said "countryside valley" — "countryside" is itself a residential
    # prior on top of the paved road (era-5 first roll: farmhouses on BOTH chains at 0.5,
    # while era-4's plain "valley" wording passed 2 of 3). Plain "valley" everywhere.
    # Even de-"countryside"d, era 5 at denoise 0.5 drew habitation on BOTH chains again
    # (s69: cottage + car + traffic signs; s70: village rows + walking figures): the paved
    # road + steel bridge package implies road users, and those are the era markers, so
    # there is no carrier left to remove. Era-5 cells run at P3BG_DENOISE=0.42 instead —
    # the clean locked era-4 parent constrains the invention while the road/bridge upgrade
    # is local enough to still land.
    # era-5 v3: denoise 0.42 killed the habitation but real-world traffic signage survived a
    # third roll (s69/s70 at 0.5, s73 at 0.42: hazard boards, warning triangles, striped
    # discs) plus a dashed centerline — "paved road" is an asphalt-era prior and signage
    # rides on it. A cobbled stone road still reads as the paving upgrade over era-4's dirt
    # ruts, and the steel truss bridge stays the loud era marker; cobble predates signage.
    # era-5 v4: the cobble swap worked (no realistic sign set, no centerline) but s82 still
    # grew ONE pink roundel sign at a hedge gap plus meadow figures, a grazing cow and a
    # treeline house. Signs spawn on road-edge verticals -> occupy the edges ("lined with
    # unbroken trimmed hedges"); figures/livestock fill the meadow -> pin it with the proven
    # democracy-plaza counter-wording ("completely deserted"). Denoise stays 0.42.
    # era-5 v5: v4's pins held where they pointed (s86: no figures, livestock, signs) but
    # habitation moved to the unpinned bands — a windowed house in the distant treeline, a
    # cottage in the meadow edge, a red shed + yellow crate on the riverbank. 7/7 era-5
    # rolls invented civilization somewhere: road+bridge implies a destination, so every
    # empty band must be occupied, not just the road and meadow. Occupy the far band with
    # unbroken wild forest and the banks with rocks and reeds. Denoise stays 0.42.
    # era-5 v6 (chain 53 only; chain 52 locked s95 on v5): both chain-53 v5 rolls grew a
    # roadside sign where a hedge/fence line ends at the road (s98 fence-corner signboard,
    # s101 lit orange sign at the bridge approach) — "unbroken" pins the hedge line but its
    # ENDS are unoccupied verticals and 2/2 says the slot, not the seed, is the problem.
    # Chain 52's passing s95 filled that exact slot by itself with benign brick parapet
    # pillars, so name that: capped stone pillars at the bridge ends. s101's other junk
    # (bottle, rag, plank artifact, barge, gate panel, twin bridge) was bad-seed density;
    # if it persists, drop chain 53 era-5 to P3BG_DENOISE=0.35 next.
    # era-5 v7 (chain 53): the 0.35 leash backfired — the parent meadow's dense rock/bush
    # blobs get REINTERPRETED at 0.35 (s107 crate/hooks/sparkle, s110 toy creatures, a
    # greenhouse, a hut, lantern finials on the named pillars), while both 0.42 rolls had
    # exactly two defects each, all sign-class, and v6's pillars killed that slot. Back to
    # 0.42, and close the last recurring slot: pillar TOPS sprout lamps cross-chain (globe
    # lamps s105, lanterns s110) — name the finial ("topped with plain stone balls", the
    # shape chain 52's passing s108 drew by itself).
    # era-5 v8 (chain 51 rebuild; chains 52/53 era-5 cells locked on s95/s113): chain 51's
    # meadow breeds occupants without the surface pin — 2/3 rolls put things ON it (s137
    # orange vehicle-shaped object + egg mound, s139 a white tent AND a red-roofed shed)
    # while eras 3/4 only closed after "of plain unbroken short grass" was named. Port it.
    # s138's junk (open book on the grass, shell pair on the parapet, flag-post in the
    # hedge) was junction-zone bad-seed density, classes not repeated since.
    5: "a vast uninhabited valley, a straight cobbled stone road lined with unbroken trimmed hedges, a steel truss bridge over the river with rocky reed-covered banks, low stone pillars topped with plain stone balls at the bridge ends, a wide flat completely deserted meadow of plain unbroken short grass across the middle ground, an unbroken dense wild forest treeline beyond, distant blue mountains, clear bright sky",
    # era-6 v2: the first era-6 roll ever (s99, denoise 0.5) over-invented beyond any prior
    # plate — a van + two cars, dozens of walking/picnicking figures, occupied benches, a
    # ridge fortress complex. "Manicured parkland" plus pathways begs for park visitors the
    # way era-5's road+bridge begged for a destination, and 0.5 gives the prior room to win.
    # Port the full era-5 v5 occupier set onto era-6's markers (hedged pathways, deserted
    # meadow, reed-covered banks, forest treeline) and run era-6 at 0.42 like era 5.
    # era-6 v3: v2 at 0.42 cut the density (no cars, no ridge fortress) but figures walked
    # the paths again (~6 robed walkers) and park furniture kept spawning (planter pedestal,
    # plant trellis, goal-frame in a bed, traffic cone) — figures AND furniture are 2/2 on
    # era-6 rolls. The proven meadow pin held both times, so pin the paths the same way
    # ("empty") and rename the venue noun to a surface: "manicured parkland" is a public
    # park that implies visitors and their furniture; "pristine manicured lawns" is grass.
    # Denoise stays 0.42; if figures survive v3, drop era-6 to P3BG_DENOISE=0.35.
    # era-6 v4: v3 killed the figures (0 walkers, s105) and the invention count keeps falling
    # (s99 ~40, s102 ~10, s105 ~5), but path-verge street furniture is now 3/3 (star pole ->
    # traffic cone -> globe lamps + bollards + blank placard + garden stake + lawn balls),
    # clustered at the bridge approaches and open lawn. Name the bridge-end slot with the
    # proven filler (era-5 v6 pillars; clean rolls draw exactly that there) and pin the lawn
    # band with "unbroken" (the adjective that holds treelines and hedges shut).
    # Denoise stays 0.42 to protect the arch-bridge marker; 0.35 is the next fallback.
    # era-6 v5: the 0.35 trial (s111) reinterpreted parent blobs into furniture (white
    # trestle table, orange spade sign, grey slab pair) AND regressed the white-bridge
    # marker to X-truss railings — era-6 stays at 0.42, where the v-series was converging
    # (mass -> 7 -> 6 -> 4 defects). v5 names the two residual slots: path edges keep
    # growing slab/headstone pairs (s108, s111) -> "edged with smooth pale curbstones";
    # pillar tops sprout lamps cross-chain -> ball finials, synced with era-5 v7.
    # era-6 v6: v5's named fixes all held (curbstones ended the slab pairs, ball finials
    # landed, bridge perfect, no lamps) but the panel-on-post sign generator is 3/3 across
    # different path-adjacent spots (blank placard s105, orange spade s111, blank diamond
    # panel s114) — paths imply wayfinding and no per-spot occupier can cover every verge.
    # Give the slot its desire in benign form, the fix pattern that closed every other
    # slot: name "low stone waymark pillars" along the paths (pillar family, benign 4/4).
    # s114's canister and yellow guardrail were first occurrences (seed noise).
    # era-6 v7 (chain 52 only; chain 53 re-rolls on v6 — its s117 grew ZERO signs on the
    # same v6 wording from its own parent, so the sign generator is bound to chain 52's
    # s95 parent composition, not the wording): s116 was the 4th sign occurrence (orange
    # diamond at the far bridge approach, plus a green pictogram panel INSET in a waymark
    # pillar) and the 2nd standing-stone meadow occupant (colored stone circle after s108's
    # headstones). Three targeted occupiers: "plain" on the waymark pillars (the adjective
    # that keeps surfaces uncarved), slender dark cypress trees flanking the bridge
    # approaches (cypresses render benignly in every roll; they fill the vertical-accent
    # slot the signs take), and the CITY[3] v3 meadow-surface pin ("of plain unbroken
    # short grass"). s116's mountain white blobs + gold roundels were first occurrences
    # (seed noise).
    6: "a vast uninhabited valley, smooth curved empty pathways edged with pale curbstones and low plain stone waymark pillars, winding across unbroken pristine manicured lawns on the far flanks, a sleek white bridge over the clean winding river with rocky reed-covered banks, low stone pillars topped with plain stone balls at the bridge ends, slender dark cypress trees flanking the bridge approaches, a wide flat completely deserted meadow of plain unbroken short grass across the middle ground, an unbroken dense wild forest treeline beyond, distant blue mountains, luminous clear sky",
}

# Remaining plates (txt2img). Subject rules already §14-standing: battle plates keep a wide
# empty middle ground (both unit lines composite there); every cloth/sign surface is occupied
# by a single named emblem or absent; no profession nouns; era-appropriate props only. The
# route_map / battle_field / battle_riot subjects are the mock-proven wordings, kept verbatim.
PLATES = {
    "route_map": (
        "an aged parchment map of a small river valley region, a walled town at the center, winding roads to nearby villages, a forest, a mountain pass and a river ford, small ink landmarks, empty parchment margins",
        MAPSTYLE),
    "battle_tax": (
        "an open farmland skirmish field, golden wheat plots and hay bales behind a low wooden fence, a wide flat empty dirt field across the middle ground, distant farm hills, clear morning sky",
        STYLE),
    "battle_field": (
        "an open countryside battlefield, rolling grass meadows with sparse trees and distant blue hills, wide empty ground across the middle, clear midday sky",
        STYLE),
    "battle_hidden": (
        "an eerie scorched clearing under a pale green-tinted sky, tall alien monolith stones leaning at odd angles, faint glowing mist hugging the ground, twisted leafless trees at the edges, wide flat empty ground across the middle",
        STYLE),
    # riot street v3: shopfronts are unfixable sign carriers at plate scale — v1 fascias
    # printed gibberish even with occupied banners, and v2's "boarded up shopfronts" grew
    # painted name boards ABOVE the boards. Remove the carrier: a residential street has no
    # fascias at all (same move as banning farm plots from the city lineage).
    "battle_riot": (
        "a narrow city street of plain stone houses with closed wooden shutters, blocked by makeshift barricades of overturned carts, crates and sandbags, cloth banners each painted with a single large red fist emblem, thin smoke rising, empty cobblestone ground in the foreground",
        STYLE),
    # democracy square v3: plaza subjects pull pedestrians — v1 drew crowds 3/3, and v2's
    # "completely deserted" only thinned them (3/3 still had figures at the colonnade). The
    # venue noun is the carrier ("public square" invites the public): v3 renames the venue,
    # adds an early-morning vacancy cue, and occupies the vacancy with drifting leaves. The
    # open bottom-right pavement is also the class's signature magnet (4 fake signatures in
    # 6 rolls landed there) — occupy that corner with a crumpled emblem-bearing banner.
    # The scales-emblem banners themselves were clean on every seed from the start.
    "battle_democracy": (
        "a vast abandoned monumental plaza in the cold light of early morning, a marble fountain and stone colonnades, cloth banners each painted with a single large golden balance scale emblem, a toppled bronze statue lying by the fountain, a torn banner with the same golden scale emblem lying crumpled on the paving in the near right corner, scattered dead leaves drifting over the stones, wide flat empty paving across the middle ground, overcast sky",
        STYLE),
    # civwar v2: "scattered round shields" invited decorated faces (a rising-sun flag pattern,
    # §8 real-world emblem class) — occupy the shield surface with materials, same move as
    # banner emblems. v1 also drew 2 fake signatures on the dirt foreground (no prompt lever;
    # seed bump + corner zoom is the only control).
    "battle_civwar": (
        "a vast open war plain scarred with trenches and earthworks, broken siege engines and scattered plain round wooden shields with iron bosses, tall poles each bearing a single plain crossed-swords banner, wide flat empty ground across the middle, dramatic storm clouds",
        STYLE),
    "battle_worldwar": (
        "a scorched world battlefield under a dark red sky, burning ruins and shattered walls on the far horizon, cratered black earth and drifting ash, wide flat empty ground across the middle",
        STYLE),
    # title v2: 4 of 6 v1 rolls failed on figure/glyph noise INSIDE the settlement (s52
    # pseudo-figures, s53 wall letterforms, s76 tower figure + friezes, s85 a glyph-debris
    # noise field on the lantern-lit plaza). The open lit courtyard is the magnet — bright
    # empty ground begs for a market crowd. Move the light into the windows (lit walls are
    # features, lit ground is an invitation) and add the sleeping vacancy cue.
    # title v3: v2's window light held but s90 drew the settlement CLOSE (a fort filling the
    # frame) and its courtyard again grew a lantern gathering, plus a corner signature. The
    # passing rolls (s51, s75) both drew the settlement small; a close settlement has an
    # interior to fill, a distant one doesn't. Pin the distance — which is also the plate's
    # concept (dwarfed = insignificant).
    # title v4: the distance pin worked (s93: small walled settlement, clean interior) but
    # s90/s93 both signed the bottom corner — 2/2 since the wide-poster framing arrived,
    # vs 0/4 before it. Same counter as democracy's crumpled banner: occupy the corners
    # with a named object (rocky outcrops, matching the composition s93 already chose).
    "title": (
        "a tiny sleeping walled settlement far in the distance, warm lantern light glowing from its windows, nestled in an immense river valley, dwarfed by towering mountain ranges under a vast twilight sky with early stars, a large open sky above, dark rocky outcrops framing the near foreground corners",
        STYLE),
    # ending_survive v2: the foreground hilltop grew figure-shapes on 3 of 5 v1 rolls (s77 a
    # melted overlook figure, s88 a red-capped gnome-face behind the cypress; even passing
    # s52's overlook figure was invented). "seen from a high hilltop" leaves an empty ledge
    # that begs for a viewer standing on it — occupy the ledge with tall grass and
    # wildflowers as the named foreground subject.
    "ending_survive": (
        "a golden sunrise flooding a prosperous river valley seen from a high hilltop meadow of tall grass and wildflowers, terraced fields and warm rooftops below, birds crossing a large open glowing sky",
        STYLE),
    # ending_collapse v2: all three v1 rolls failed §8 on the stone faces — s51 drew a
    # gravestone cross on the "toppled monument" (real-world religious symbol), s52 carved a
    # garbled pseudo-inscription into a wall block, s53 doodled corner glyphs (heart + curls)
    # on a rock face. Blank ruin stone is an inscription magnet and "monument" carries a
    # gravestone prior: occupy the faces with thick ivy/moss and name the monument an obelisk.
    "ending_collapse": (
        "crumbling abandoned stone ruins under a grey overcast sky, a toppled stone obelisk and broken walls blanketed in thick ivy and moss, cold mist drifting through, muted faded colors, a large open sky above",
        STYLE),
}


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


def gen_plate(plate_id: str, seed: int, resume: bool = False) -> None:
    core, suffix = PLATES[plate_id]
    stem = f"p3_bg_{plate_id}_s{seed}"
    if resume and os.path.exists(f"{OUT}/{stem}_00001_.png"):
        print(f"=== {stem} (exists, skipped)", flush=True)
        return
    run(stem, [sys.executable, "comfy_run.py", T2I,
               "--seed", str(seed), "--prompt", core + suffix,
               "--width", str(W), "--height", str(H),
               "--prefix", f"phase3-backgrounds/{stem}", *LORA_ARGS])


def gen_city_cell(state: dict, chain: int, era: int, seed: int) -> None:
    stem = f"p3_bg_city_era{era}_s{seed}"
    cmd = [sys.executable, "comfy_run.py",
           "--seed", str(seed), "--prompt", CITY[era] + STYLE,
           "--prefix", f"phase3-backgrounds/{stem}", *LORA_ARGS]
    if era == 1:
        cmd[2:2] = [T2I]
        cmd += ["--width", str(W), "--height", str(H)]
    else:
        src_stem = state["city"][str(chain)][str(era - 1)]["stem"]
        cmd[2:2] = [I2I]
        cmd += ["--image", f"{OUT}/{src_stem}_00001_.png", "--denoise", str(DENOISE)]
    run(stem, cmd)
    state.setdefault("city", {}).setdefault(str(chain), {})[str(era)] = {
        "stem": stem, "seed": seed, "prompt": CITY[era] + STYLE,
        "denoise": DENOISE if era > 1 else None}
    save_state(state)


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "plates"
    state = load_state()
    if mode == "plates":
        for seed in SEEDS:
            if str(1) not in state.get("city", {}).get(str(seed), {}):
                gen_city_cell(state, seed, 1, seed)
        for plate_id in PLATES:
            for seed in SEEDS:
                gen_plate(plate_id, seed, resume=True)
    elif mode == "city_era":
        era = int(sys.argv[2])
        if "--redo" in sys.argv:
            for spec in sys.argv[sys.argv.index("--redo") + 1:]:
                chain, seed = spec.split(":")
                gen_city_cell(state, int(chain), era, int(seed))
        else:
            for chain in SEEDS:
                if str(era) in state.get("city", {}).get(str(chain), {}):
                    continue
                gen_city_cell(state, chain, era, chain)
    elif mode == "redo":
        gen_plate(sys.argv[2], int(sys.argv[3]))
    else:
        raise SystemExit(f"unknown mode {mode}")
    print("BATCH_DONE", flush=True)


if __name__ == "__main__":
    main()
