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
# Five cores carry fixes for defects the exploration raws still show (review-brief-units-topdown.md):
# bomber e4-e6 rendered nose-LEFT under a suffix that says nose-right, and privateers e4/e5
# rendered facing the camera. Both are fixed by front-loading the heading into the subject clause
# instead of trusting the suffix — the same fix the exploration needed for figures.
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
    "barrier":      f", game fortification sprite, {_OVERHEAD}, the barrier running vertically from the top edge to the bottom edge of the frame, {_ISO}",
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
        "three identical tribal hunters in hide tunics, each gripping a Y-shaped wooden slingshot forward at arm's length, the rear hand pinching a small leather pouch against the cheek with a round gray stone bulging inside it, two thick leather bands running taut from the pouch forward to the two fork tips, a small hide pouch of stones on each belt, red feathers tied in their hair, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical archers in green tunics drawing tall wooden longbows, quivers of red-fletched arrows at their hips, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical crossbowmen in padded jackets and iron kettle helmets aiming heavy crossbows, red-fletched bolts in belt quivers, simplified stylized figures with rounded chunky bodies and no facial features",
        "three identical skirmisher soldiers in plain jackets and soft black peaked caps, each aiming his own musket with both hands, simplified stylized figures with rounded chunky bodies and no facial features",
        "exactly two identical soldiers, in hooded leaf-camouflage cloaks, one kneeling aiming a long scoped rifle on a bipod, the other crouching beside him holding a brass spotting scope, simplified stylized figures with rounded chunky bodies and no facial features",
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
        "a tracked self-propelled howitzer on continuous steel track links with a long elevated gun barrel, painted plain olive drab with a single white circle on the hull side, a crew member standing on a wooden ladder against the hull holding a cleaning rod, a simplified chunky vehicle shape with minimal surface detail",
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
        "a row of tall rough wooden plank shields lashed together with rope into a standing wall, spear tips poking over the top, red cloth strips tied at the joints, a simplified chunky shape with minimal surface detail",
        "a tight freestanding wall of overlapping kite shields each embossed with a plain raised ring pattern, a clean level top edge, a simplified chunky shape with minimal surface detail",
        "a stone battlement wall segment with a crenellated top and arrow slits, an unbroken smooth masonry face and a clean level parapet line, a simplified chunky shape with minimal surface detail",
        "a chest-high wall of stacked burlap sandbags in even rows with wooden support posts, the sandbag surface soft and rounded throughout, a simplified chunky shape with minimal surface detail",
        "a tall fence of taut electrified steel wire mesh strung between dark metal posts on a row of low concrete base blocks, each post topped with a single rounded metal cap holding one white ceramic insulator flush against it, a simplified chunky shape with minimal surface detail",
        "a segment of modular barrier wall of smooth matte gray fiber-reinforced polymer panels bolted to a steel frame, deployable metal struts at its base, a simplified chunky shape with minimal surface detail",
    ],
    "anti_air": [
        "a slanted shelter roof of plain overlapping brown and tan raw hides on stout timber posts, several arrows stuck in the hide roof, bare trampled earth below, a simplified chunky shape with minimal surface detail",
        "a tall timber arrow tower with a roofed shooting platform and wooden hoardings, a red cloth strip tied to a corner post, a simplified chunky shape with minimal surface detail",
        "a round stone defense tower with machicolations and an open flat unroofed stone top with no roof and no tiles and no timber shelter, a mounted ballista aimed skyward on it loaded with a plain wooden bolt that does not glow, a simplified chunky shape with minimal surface detail",
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
    "anti_air": ["emplacement", "emplacement", "emplacement", "emplacement", "vehicle", "vehicle"],
    "enemy_weak": ["figure_one", "figure_one", "figure_one", "figure_one", "figure_one", "figure_one"],
    "enemy_mid": ["figure_multi", "figure_multi", "figure_multi", "figure_multi", "figure_multi", "figure_multi"],
    "enemy_hard": ["figure_one", "figure_one", "figure_one", "figure_one", "vehicle", "figure_one"],
}

# lines that unlock later start their chain at this era (txt2img root there), per the
# pick-gate design rulings recorded in phase3_units_batch.py.
START_ERA = {"elite_forces": 2, "artillery": 3, "bomber": 4, "holy_warriors": 4, "privateers": 3}
