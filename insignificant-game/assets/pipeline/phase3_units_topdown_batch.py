# phase3_units_topdown_batch.py — W14.8 top-down re-render of the unit / fortification /
# enemy-tier sprites (ADR-0009: the battle scene is top-down). Same machinery and the same
# era-gated img2img discipline as phase3_units_batch.py, which this supersedes for the
# battlefield classes; only the camera changes. Framing suffixes are style bible §3's top-down
# row, split by subject kind because a barrier, an aircraft and a rank of men need different
# orientation cues.
#
# Subject cores for the 11 player lines are the wording the top-down exploration validated
# (docs/tools/topdown_demo_sprites.json; findings in docs/explore-topdown-battle-and-units.md §4):
# steep-angle wording beats a vague "three-quarter top-down", orientation must be pinned
# explicitly or an X-flip has nothing to mirror, and the subject's count must agree with the form
# tail's count or the model invents a crowd. The 18 abstract enemy tiers had no top-down wording,
# so their cores are the pick-gated side-view subjects re-framed left-facing.
#
# Five cores carry a heading clause front-loaded into the subject instead of left to the framing
# suffix (review-brief-units-topdown.md). It was authored for two cells and is inert on three:
#   - privateers e4/e5 GENUINELY needed it. The exploration rolls face the camera, because a lone
#     figure has no rank geometry to imply a heading and the suffix alone is too weak. The sweep
#     confirms the fix: all four seeds of each now stride right.
#   - bomber e4/e5/e6 did NOT need it. They already rendered nose-right, and the sweep renders them
#     nose-right too. The clause is kept because it is harmless and makes the roster consistent,
#     but do not cite the bombers as evidence that suffix headings fail.
#
# anti_air starts at era 4, not era 1: ADR-0006 retired the era 1-3 forms (擋箭棚/箭樓/城防塔)
# outright — "no air exists before 工業, so no anti-air exists either" — and core/data/cards.gd
# agrees (era_names ["", "", "", "高射砲", "防空飛彈", "雷射攔截網"]). The exploration table this
# module lifted its wording from still carried the three stranded cells, so the first sweep
# rendered 12 candidates for forms that do not exist in the game. They are not re-rendered and
# not picked.
#
# Constants are imported by phase3_units_topdown_wave.py (the era-gated driver).
import os

SEEDS = [91, 92, 93, 94]
DENOISE = float(os.environ.get("P3UT_DENOISE", "0.55"))
T2I = "workflows/krea2_lora_txt2img.json"
I2I = "workflows/krea2_lora_img2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-units-topdown")

_OVERHEAD = "steep high-angle view looking straight down from directly above"
_ISO = "centered, isolated on a plain light gray background"

# kind -> framing suffix. The orientation clause is the load-bearing half: a barrier runs across
# the field, an emplacement has no heading, everything else points at the enemy. "{edge}" is
# filled per line, because the abstract enemy tiers are always the opposing side.
SUFFIX = {
    "figure_multi": f", game unit sprite, {_OVERHEAD}, the whole group oriented toward the {{edge}} edge of the frame, bodies and weapons pointing {{edge}}, {_ISO}",
    "figure_one":   f", game unit sprite, {_OVERHEAD}, the figure oriented toward the {{edge}} edge of the frame, body and weapon pointing {{edge}}, {_ISO}",
    "vehicle":      f", game unit sprite, {_OVERHEAD}, the vehicle oriented toward the {{edge}} edge of the frame, its barrel pointing {{edge}}, {_ISO}",
    "air":          f", game unit sprite, {_OVERHEAD}, the aircraft oriented toward the {{edge}} edge of the frame, its nose pointing {{edge}}, {_ISO}",
    # "standing vertically in the middle of the frame" was meant as "its length runs top to bottom",
    # and the model read it as "upright": it rendered the wall's VERTICAL FACE in three-quarter
    # perspective, giving a tower (e3), a fence seen side-on (e5) and one propped-up shield (e2).
    # From directly above a wall IS its top surface and nothing else, so the frame clause now names
    # the axis without the word "vertically" and states the top face outright. This is the same
    # mechanism as the eye-level drift finding: the camera goes wherever the subject's readable
    # identity was placed, so identity has to be put on the top.
    # Round 3 fixed the camera (these are genuinely top-down now) but every segment came back
    # TAPERED — wide at the bottom of the frame, narrowing toward the top, a vanishing point along
    # its own length — and several ran off the bottom edge. That is the same failure the battle
    # plates had, and the plate probe diagnosed it: scene language ("its length running from near
    # the top of the frame down to near the bottom") names a viewer, and a named viewer gets a
    # perspective. The plate fix was to ask for a repeating pattern of IDENTICAL UNITS instead, and
    # it works at the shipped frame. Same move here: a wall is a short row of identical modules,
    # stated as a count with a constant width, which also removes the reason to touch either edge.
    "barrier":      f", game fortification sprite, {_OVERHEAD}, a short straight row of about six identical modules butted end to end into one self-contained wall segment, every module the same size and shape as every other and the segment exactly the same width along its whole length, its flat top surface turned toward the camera, a finished end cap closing the row at each end well inside the frame, bare open ground on all four sides of the segment, {_ISO}",
    "emplacement":  f", game fortification sprite, {_OVERHEAD}, the emplacement oriented toward the {{edge}} edge of the frame, {_ISO}",
    "fort_vehicle": f", game fortification sprite, {_OVERHEAD}, the vehicle oriented toward the {{edge}} edge of the frame, its barrel pointing {{edge}}, {_ISO}",
}

FORT_LINES = {"shield_wall", "anti_air"}
ENEMY_LINES = {"enemy_weak", "enemy_mid", "enemy_hard"}


def suffix_for(line: str, era: int) -> str:
    """Framing suffix for one cell. `kind` is per-era: lines change subject type mid-chain
    (cavalry becomes a tank at era 5, engineers at era 5 only, anti_air from era 5)."""
    kind = KINDS[line][era - START_ERA.get(line, 1)]
    if kind == "vehicle" and line in FORT_LINES:
        kind = "fort_vehicle"
    return SUFFIX[kind].format(edge="left" if line in ENEMY_LINES else "right")


def prompt_for(line: str, era: int) -> str:
    return LINES[line][era - START_ERA.get(line, 1)] + suffix_for(line, era)


# line -> [subject core, one per era from the line's start era]; KINDS runs parallel to it.

LINES = {
    "infantry": [
        "three identical tribal warriors in fur and hide swinging heavy wooden clubs, red war paint stripes on their arms, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical spearmen standing in a tight rank, each of the three men gripping his own single spear in one hand and a round shield in the other, bronze helmets with red horsehair crests, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical foot soldiers in chainmail and open helmets with swords raised, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical musketeer soldiers standing in a staggered line, each of the three men holding his own separate musket with its fixed bayonet pointing straight up, plain dark blue wool coats with brass buttons over plain white waistcoats, tall black shako hats, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical soldiers in olive drab uniforms and steel helmets with rifles, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical soldiers in bulky powered armor suits with infrared visor slits and oversized metal gauntlets, simplified stylized figures with rounded chunky bodies and no facial features",
    ],
    "archers": [
        "three identical tribal hunters in hide tunics, each holding a long leather sling strap hanging slack from his raised fist with a round gray stone cradled in its wide middle pouch, the loose end of the strap gripped in the same fist, a small hide pouch of stones on each belt, red feathers tied in their hair, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical archers in green tunics drawing tall wooden longbows, quivers of red-fletched arrows at their hips, simplified stylized figures with rounded chunky bodies and no facial features",
        # Rounds 1-2 both grew the prod into a longbow-scale recurve bolted to a stock. Surviving
        # 15th-century military crossbows put the prod span at 60-81cm against a 70-96cm tiller, so
        # prod:tiller is 0.8-1.0, not 2:1, and a steel prod is a shallow single arc with no recurved
        # tips (recurved crossbow limbs are a fantasy-art tell). The fix is to state the ratio and
        # the flatness rather than just say "short": "short" is relative and the model had no anchor.
        "three identical crossbowmen in padded jackets and iron kettle helmets, each holding his own "
        "heavy crossbow level and aimed forward, each crossbow a cruciform shape of a long narrow "
        "wooden tiller running back to the shoulder with a bolt groove down its centreline and one "
        "stubby steel prod mortised crosswise at the muzzle end, the prod no wider than the tiller is "
        "long and shaped as a single shallow almost straight bar tapering from a thick centre to "
        "forged tip nocks, the bowstring drawn back to a wide shallow obtuse V, a D-shaped iron "
        "stirrup at the muzzle, red-fletched bolts in belt quivers, simplified stylized figures with "
        "rounded chunky bodies and no facial features",
        "three identical skirmisher soldiers in plain jackets and soft black peaked caps, each aiming his own musket with both hands, simplified stylized figures with rounded chunky bodies and no facial features",
        "exactly two identical soldiers in hooded leaf-camouflage cloaks, both striding forward on their own two legs, one carrying a long scoped rifle levelled forward at his shoulder, the other carrying a brass spotting scope in one hand, simplified stylized figures with rounded chunky bodies and no facial features",
        "two identical soldiers, wearing helmets, in gray armored suits with a clean unmarked look and no stains, marks or streaks of colour anywhere on the fabric, one shouldering a boxy missile launcher with the same solid all-white disc on its side and a glowing red targeting lens pointed forward, the other carrying a folded tripod radar dish, simplified stylized figures with rounded chunky bodies and no facial features",
    ],
    "cavalry": [
        "three identical tribal riders in furs mounted on shaggy horned beasts with red cloth harnesses, simplified stylized figures with rounded chunky bodies and no facial features",
        "a wooden war chariot pulled by two horses, a driver and a spearman aboard, a plain red pennant streaming from the chariot rail, simplified stylized figures with rounded chunky bodies and no facial features",
        "exactly two identical armored knights in plain bare steel helmets, each gripping one raised lance in the fist and the reins in the other hand, each mounted on one horse draped in a plain red cloth caparison, the horses wearing smooth plain rounded steel face plates, the pair riding alone across open bare ground, simplified stylized figures with rounded chunky bodies and no facial features",
        "two identical dragoon cavalrymen galloping forward, bare-headed horses with plain leather bridles, each rider wearing a brass comb-crested helmet with a black horsehair mane, plain green coats with red cuffs, each rider gripping exactly one short flintlock carbine one-handed and angled forward, his other hand holding only the reins, both riders otherwise empty-handed, simplified stylized figures with rounded chunky bodies and no facial features",
        "a heavy battle tank standing alone on open bare ground with its long cannon barrel pointing forward, riveted armor plates, a simplified chunky vehicle shape with minimal surface detail",
        "a sleek unmanned tracked combat vehicle with a sensor dome, a gunmetal hull with a fine repeating grid of recessed panel seam lines and no other surface detail, no roundel, no insignia, no squadron marking, no badge, no lettering and no stencil anywhere, a simplified chunky vehicle shape with minimal surface detail",
    ],
    "engineers": [
        "three identical tribal laborers in hide tunics carrying log beams and stone hammers, coils of rope over their shoulders, red cloth headbands, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical builders in leather aprons, one laying stone blocks with a trowel, one carrying a wooden beam with a plain red cloth strip tied around its end, one swinging a big wooden mallet, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical sappers in iron kettle helmets and brown leather jerkins pushing a tall standing shield wall of rough wooden planks that rests on the ground on cart fixed at its lower edge, one carrying a pickaxe, one a bundle of sticks, plain red shoulder sashes, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical soldiers in plain gray uniforms with red collar trim and soft gray field caps, one carrying a short flat wooden plank bridge section tucked upright under one arm, one shouldering a shovel, one carrying a coil of wire in both hands, simplified stylized figures with rounded chunky bodies and no facial features",
        "a yellow armored engineering vehicle with a bulldozer blade and a crane arm and a single white circle on its hull side, two identical soldiers sit inside the vehicle in olive uniforms and steel helmets with head out, a simplified chunky vehicle shape with minimal surface detail",
        "two identical soldiers in powered exo-frame suits with hydraulic arms, one carrying a folded bridge girder, one a heavy cutting torch with a glowing orange tip, simplified stylized figures with rounded chunky bodies and no facial features",
    ],
    "elite_forces": [
        "two identical royal guards, in gilded bronze armor and tall red-plumed helmets holding ornate halberds angled forward, plain purple cloaks, simplified stylized figures with rounded chunky bodies and no facial features",
        "two identical temple knights, in white surcoats over chainmail holding greatswords raised high, each surcoat bearing a single golden tree emblem, simplified stylized figures with rounded chunky bodies and no facial features",
        "two identical grenadier soldiers, in plain dark blue coats and helmets, each with a plain musket slung on a strap across his back, one holding a round dark-green grenade with a short sputtering fuse, the other shielding that fuse with a cupped gloved hand, simplified stylized figures with rounded chunky bodies and no facial features",
        "two commandos standing one behind the other, in black tactical armor, night-vision goggles with green lenses, each with both hands on his own compact rifle held angled down, simplified stylized figures with rounded chunky bodies and no facial features",
        "two identical cyborg super soldiers standing one behind the other, sleek chrome cybernetic arms and legs joined to armored torsos, each shoulder pauldron painted with a single solid unbroken white disc of flat colour with no notch, no crescent and no ring cut into or around it, a thin red accent line traces each side of the neck matching the suit's other red piping and nothing else on the neck, glowing blue eye implants and nothing else glowing anywhere on his body, each gripping one single heavy rifle with both hands and no second barrel, tube or weapon attached to it or resting anywhere near it, simplified stylized figures with rounded chunky bodies and no facial features",
    ],
    "artillery": [
        "a squat bronze bombard cannon on a timber sled aimed upward, stone cannonballs stacked beside it, a crewman in a padded jacket holding a glowing red linstock, a simplified chunky vehicle shape with minimal surface detail",
        "a field cannon with a bronze barrel resting on a two-wheeled carriage with large spoked wooden wheels, two identical gunners in plain dark blue uniforms each gripping a long bare wooden rammer staff with a cloth-wrapped head, a pyramid of black iron cannonballs, a simplified chunky vehicle shape with minimal surface detail",
        # Round 2 came back a pure broadside in 4/4 seeds: the description lived entirely on the hull
        # SIDE (a white circle on the hull side, the barrel's elevation), so the camera went to the
        # side to show it. Round 3 puts every identifying feature on the roof deck instead, and the
        # marking is gone because naming a circle on the side was itself an instruction to show the
        # side. The bare plate is occupied with weld seams rather than denied (cookbook §8.3 rung 2).
        "a tracked self-propelled howitzer seen down onto its roof, its flat armoured deck turned up "
        "toward the camera and filling the middle of the frame, a long gun barrel laid out flat along "
        "the deck, both continuous steel track runs visible as two parallel bands one along each side "
        "of the hull, round closed hatches set flush into the deck plate, lashed stowage boxes and a "
        "rolled tarpaulin strapped across the rear deck, painted a uniform olive drab broken only by "
        "weld seams and rivet lines, a simplified chunky vehicle shape with minimal surface detail",
        "a futuristic tracked railgun platform standing alone with twin long parallel magnetic rails elevated skyward, smooth matte gunmetal armor plates covered in fine recessed panel seam lines and rivets, every raised hull viewport, sensor dome and camera housing capped with a plain flat dark gray metal disc, a single white circle painted on the hull side, a simplified chunky vehicle shape with minimal surface detail",
    ],
    "bomber": [
        "a short stubby silver-gray rigid airship with a broad rounded hull, a blunt nose at the right edge of the frame, a deep rounded tail with four cruciform fins at the left edge and a large gondola slung beneath the hull, the hull covered in a fine repeating grid of rivets and thin horizontal panel seams, no roundel, no insignia, no squadron marking, no tail flash, no lettering and no stencil anywhere on the craft, a simplified chunky aircraft shape with minimal surface detail",
        "a heavy four-engine propeller bomber aircraft with the nose and cockpit at the right edge of the frame and the tail at the left edge, four propeller engines along its wings, painted a continuous plain olive drab colour with a fine repeating grid of rivets and thin panel seam lines covering the fuselage and tail fin edge to edge, no roundel, no insignia, no squadron marking, no tail flash, no lettering and no stencil anywhere on the aircraft, a simplified chunky aircraft shape with minimal surface detail",
        "a black angular flying-wing stealth bomber in flight toward the right edge of the frame, its nose at the right edge and its trailing edge at the left, its cockpit spine and every fuselage and wing surface a continuous plain matte black colour with a fine repeating grid of recessed panel seam lines and no other surface detail, no roundel, no insignia, no squadron marking, no badge, no lettering and no stencil anywhere on the aircraft, a simplified chunky aircraft shape with minimal surface detail",
    ],
    "holy_warriors": [
        "two identical musketeers in white coats standing close together, each aiming his own musket levelled forward with both hands on it and the barrel pointing toward the right edge of the frame, a single golden tree emblem on each chest, simplified stylized figures with rounded chunky bodies and no facial features",
    ],
    "privateers": [
        "a single lone bandit in a dark leather jerkin standing alone in an otherwise empty frame, gripping his short curved sword held forward, a small closed brown loot sack tied at his belt, a simplified stylized figure with a rounded chunky body and no facial features",
        "a single lone thief in a dark hooded coat and neck scarf striding toward the right edge of the frame, alone in an otherwise empty frame, gripping his short dagger held forward, a brass-cornered suitcase carried under his other arm, a simplified stylized figure with a rounded chunky body and no facial features",
        "a single lone hacker in a dark hooded field jacket striding toward the right edge of the frame, alone in an otherwise empty frame, holding his open rugged laptop in both hands, the laptop's outer lid a plain unmarked metallic surface with no logo or brand mark, a simplified stylized figure with a rounded chunky body and no facial features",
    ],
    "shield_wall": [
        "a short freestanding segment of tall rough wooden plank shields lashed together with rope into a standing wall, a finished upright end post at each end of the segment, spear tips poking over the top, red cloth strips tied at the joints, a simplified chunky shape with minimal surface detail",
        "a short freestanding barrier built from two parallel ranks of kite shields, the shields of each rank overlapping edge over edge like roof tiles and the second rank braced close behind the first, the curved outer face of every shield turned up toward the camera and embossed with a plain raised ring boss, a finished stake driven in at each end of the barrier, a simplified chunky shape with minimal surface detail",
        "a short freestanding segment of stone battlement wall seen down onto its top, a narrow flagstone wall-walk running the length of the segment with a row of square merlons along each side of the walk and an open crenel gap between every pair of merlons, a finished squared stone pier capping each end, pale mortared masonry, a simplified chunky shape with minimal surface detail",
        "a short freestanding segment of chest-high wall of stacked burlap sandbags in even rows, a finished wooden support post closing each end of the segment, the sandbag surface soft and rounded throughout, a simplified chunky shape with minimal surface detail",
        "a short freestanding segment of gabion barrier seen down onto its top, a row of square steel wire mesh cages standing side by side and packed solid with rammed earth and broken stone, the tight dark wire mesh grid wrapping every cage and clearly visible over the fill, a heavy timber corner brace closing each end of the row, the packed earth top surface turned up toward the camera, a simplified chunky shape with minimal surface detail",
        "a segment of modular barrier wall of smooth matte gray fiber-reinforced polymer panels bolted to a steel frame, deployable metal struts at its base, a simplified chunky shape with minimal surface detail",
    ],
    "anti_air": [
        "an anti-aircraft flak cannon with a long barrel angled skyward on a cross-shaped steel mount resting directly on flat bare ground, a ring gunsight, stacked shell crates beside it, painted plain olive drab, a simplified chunky shape with minimal surface detail",
        "a tracked vehicle painted plain olive drab with a single white circle on the hull, carrying four white surface-to-air missiles on rails angled skyward, a simplified chunky vehicle shape with minimal surface detail",
        "a boxy laser interception turret on a rotating gimbal mount, a single large circular optical lens aperture aimed skyward, two small camera pods mounted beside the aperture, matte olive drab armor housing with a single solid unbroken white disc of flat colour painted on its side, the disc a complete circle with no notch and no crescent cut into it, a simplified chunky vehicle shape with minimal surface detail",
    ],
    "enemy_weak": [
        "a lone tribal levy warrior in a plain dark hide tunic and a simple leather cap, gripping a wooden spear with both hands, striding toward the left edge of the frame, alone in an otherwise empty frame, a simplified stylized figure with a rounded chunky body and no facial features",
        "a lone militia spearman in a plain dark linen tunic and a simple leather helmet, holding a spear in one hand and a small round wooden shield in the other, striding toward the left edge of the frame, alone in an otherwise empty frame, a simplified stylized figure with a rounded chunky body and no facial features",
        "a lone levy crossbowman in a plain dark padded gambeson and a simple iron cap, aiming a light crossbow toward the left edge of the frame, alone in an otherwise empty frame, a simplified stylized figure with a rounded chunky body and no facial features",
        "a lone militiaman in a plain dark brown coat and a soft cap, aiming a musket toward the left edge of the frame, the musket's muzzle end a single round barrel tip capped with one plain front sight nub, a long bayonet blade mounted flush against the barrel in one thin metal socket ring and no other stud, tube or second barrel anywhere beside it, a rolled gray blanket strapped diagonally across his back, alone in an otherwise empty frame, a simplified stylized figure with a rounded chunky body and no facial features",
        "a lone reservist soldier in a plain dark gray uniform and a soft field cap, both hands on his own rifle held angled down toward the left edge of the frame, alone in an otherwise empty frame, a simplified stylized figure with a rounded chunky body and no facial features",
        "a lone volunteer soldier in a plain dark gray jacket with a few plain dull metal studs on the chest and a compact visor over his eyes, both hands on his own compact energy carbine held angled down toward the left edge of the frame, alone in an otherwise empty frame, a simplified stylized figure with a rounded chunky body and no facial features",
    ],
    "enemy_mid": [
        "two identical disciplined warriors in matching dark hide-and-bone armor, each holding one stone-tipped spear in his own fist, simplified stylized figures with rounded chunky bodies and no facial features",
        "two identical professional soldiers in matching dark iron scale armor and plain dark helmets, each with one short sword in his own fist and a round shield in the other hand, simplified stylized figures with rounded chunky bodies and no facial features",
        "two identical men-at-arms in blackened chainmail and dark kettle helmets, each holding one poleaxe upright in his own hands, a kite shield slung on each back, simplified stylized figures with rounded chunky bodies and no facial features",
        "two identical line soldiers in matching dark gray uniforms and black shakos, each aiming his own musket, simplified stylized figures with rounded chunky bodies and no facial features",
        "two identical soldiers in matching dark combat uniforms, armor vests and helmets, each with both hands on his own rifle held angled down, a plain orange armband of unbroken solid colour on each upper sleeve, simplified stylized figures with rounded chunky bodies and no facial features",
        "two identical soldiers in matte black powered vests, each with both hands on his own solid matte black heavy rifle held angled down, the rifle body plain metal with no lit parts, simplified stylized figures with rounded chunky bodies and no facial features",
    ],
    "enemy_hard": [
        "a towering elite champion in heavy dark bone-and-hide armor swinging a massive stone maul with both hands, striding toward the left edge of the frame, alone in an otherwise empty frame, a simplified stylized figure with a rounded chunky body and no facial features",
        "a towering elite champion in heavy dark bronze plate armor holding a huge two-handed cleaver blade, a tower shield embossed with a plain raised ring pattern standing at his side, striding toward the left edge of the frame, alone in an otherwise empty frame, a simplified stylized figure with a rounded chunky body and no facial features",
        "a towering elite knight in polished black plate armor with a smooth rounded greathelm, both hands swinging a massive two-handed flail, a dark cape, striding toward the left edge of the frame, alone in an otherwise empty frame, a simplified stylized figure with a rounded chunky body and no facial features",
        "a hulking soldier in a heavy dark iron cuirass and a smooth rounded steel helmet, both hands carrying a hand-cranked multi-barrel gun, ammunition belts across his chest, striding toward the left edge of the frame, alone in an otherwise empty frame, a simplified stylized figure with a rounded chunky body and no facial features",
        "a heavy dark battle tank freshly painted in glossy showroom-new black enamel, every hull and turret plate smooth and bright with clean crisp reflections, a single flat solid orange stripe of one plain colour and no other colour painted on the turret, a simplified chunky shape with minimal surface detail",
        "a towering black combat mech with glowing orange eye sensors, massive clawed arms and missile pods on its shoulders, every armor plate and pod housing a plain unmarked matte black surface with no lettering and no stencilled text anywhere, striding toward the left edge of the frame, alone in an otherwise empty frame, a simplified stylized figure with a rounded chunky body and no facial features",
    ],
}

KINDS = {
    "infantry": ["figure_multi", "figure_multi", "figure_multi", "figure_multi", "figure_multi", "figure_multi"],
    "archers": ["figure_multi", "figure_multi", "figure_multi", "figure_multi", "figure_multi", "figure_multi"],
    "cavalry": ["figure_multi", "figure_multi", "figure_multi", "figure_multi", "vehicle", "vehicle"],
    "engineers": ["figure_multi", "figure_multi", "figure_multi", "figure_multi", "vehicle", "figure_multi"],
    "elite_forces": ["figure_multi", "figure_multi", "figure_multi", "figure_multi", "figure_multi"],
    "artillery": ["vehicle", "vehicle", "vehicle", "vehicle"],
    "bomber": ["air", "air", "air"],
    "holy_warriors": ["figure_multi"],
    "privateers": ["figure_one", "figure_one", "figure_one"],
    "shield_wall": ["barrier", "barrier", "barrier", "barrier", "barrier", "barrier"],
    "anti_air": ["emplacement", "vehicle", "vehicle"],
    "enemy_weak": ["figure_one", "figure_one", "figure_one", "figure_one", "figure_one", "figure_one"],
    "enemy_mid": ["figure_multi", "figure_multi", "figure_multi", "figure_multi", "figure_multi", "figure_multi"],
    "enemy_hard": ["figure_one", "figure_one", "figure_one", "figure_one", "vehicle", "figure_one"],
}

# lines that unlock later start their chain at this era (txt2img root there), per the
# pick-gate design rulings recorded in phase3_units_batch.py.
START_ERA = {"elite_forces": 2, "artillery": 3, "bomber": 4, "holy_warriors": 4, "privateers": 3, "anti_air": 4}
