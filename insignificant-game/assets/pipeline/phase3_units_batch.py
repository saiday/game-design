# phase3_units_batch.py — Phase 3 class 2b: unit / fortification / enemy-tier sprites
# (cookbook §7), era lineage via img2img (cookbook §6) exactly like the buildings class:
# each line's start era is txt2img under style bible §2-§3; each later era is img2img from the
# SAME chain's previous era at DENOISE, so one seed = one coherent era chain and the human picks
# a whole lineage. Subjects follow 卡牌 部隊卡/工事卡的時代演化總表 and 戰鬥 敵方單位級別
# (inventory.md ids). Constants are imported by phase3_units_wave.py (the era-gated driver).
import os

SEEDS = [81, 82, 83, 84]
DENOISE = float(os.environ.get("P3U_DENOISE", "0.55"))  # override per-run when a parent artifact
# is too dominant for wording to beat (§14: naming a banned object reinforces it at cfg 1)
T2I = "workflows/krea2_lora_txt2img.json"
I2I = "workflows/krea2_lora_img2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-units")

# The units suffix is pilot-proven (§14 2026-07-14 v4 round); forts swap the class noun per
# style bible §3.
SUFFIX_UNIT = ", game unit sprite, side view, centered, isolated on a plain light gray background"
SUFFIX_FORT = ", game fortification sprite, side view, centered, isolated on a plain light gray background"
FORT_LINES = {"shield_wall", "trench", "anti_air"}


def suffix_for(line: str) -> str:
    return SUFFIX_FORT if line in FORT_LINES else SUFFIX_UNIT


# line -> [subject cores, one per era from the line's start era] (era forms: 卡牌 evolution
# tables / inventory.md; enemy tiers: 戰鬥 敵方單位級別, generic hostile look in a dark/rust
# palette so they read as the opposing side at battle scale). Subject rules from the buildings
# class + v4 units pilot (§14): figures are "identical" (uniformity), every subject carries an
# inherently colored element, every flat surface is occupied or absent (shield faces get painted
# rings, vehicle hulls/fuselages get a single white circle — never real-world insignia), religion
# carries the golden-tree motif, weapons are era-appropriate, no emotion nouns, no profession
# nouns that invite signage.
LINES = {
    "infantry": [
        "three identical tribal warriors in fur and hide swinging heavy wooden clubs, red war paint stripes on their arms",                                          # 棍棒戰團
        "a tight rank of three identical spearmen with long spears, bronze helmets with red horsehair crests, round shields each painted with a plain red ring",     # 長矛方陣
        "three identical foot soldiers in chainmail and plain rounded open helmets, each raising one straight sword in the fist and gripping a kite shield in the other hand, the kite shields each painted with a plain red ring",  # 劍盾步兵 (v3: v2's "nothing else carried" NAMED the banned object and merely displaced e2's spear into a floating blade plus a curled hook overhead — fill both hands positively instead so no slot is left for it. v2: e2's spears rode down the chain as a shaft across every body, its crests as flame tongues)
        "a rank of three identical musketeer soldiers in plain dark blue coats with brass buttons, muskets with fixed bayonets leveled, tall black shako hats",      # 線列步兵
        "three identical soldiers in olive drab uniforms and steel helmets with rifles, riding in an open-topped armored truck with a single white circle painted on its door",  # 摩托化步兵
        "three identical soldiers in bulky powered armor suits with glowing blue visor slits and oversized metal gauntlets",                                         # 動力裝甲兵
    ],
    "archers": [
        "three identical tribal hunters in hide tunics, each gripping a Y-shaped wooden slingshot forward at arm's length, the rear hand pinching a small leather pouch against the cheek with a round gray stone bulging inside it, two thick leather bands running taut from the pouch forward to the two fork tips, a small hide pouch of stones on each belt, red feathers tied in their hair",  # 投石手 (v4: v3 kept hanging the stone from the fork tips on a cord — anchor the pouch+stone at the rear hand/cheek and run the bands forward from it)
        "three identical archers in green tunics drawing tall wooden longbows, quivers of red-fletched arrows at their hips",                                        # 弓箭團
        "three identical crossbowmen in padded jackets and iron kettle helmets aiming heavy crossbows, red-fletched bolts in belt quivers",                          # 弩手連
        "three identical skirmisher soldiers in plain green jackets kneeling and aiming long muskets, powder horns on red shoulder straps",                          # 火槍散兵
        "two identical soldiers in hooded leaf-camouflage cloaks, one kneeling aiming a long scoped rifle on a bipod, the other holding a brass spotting scope",     # 狙擊小隊
        "two identical soldiers in gray armored suits, one shouldering a boxy missile launcher with a glowing red targeting lens, the other carrying a folded tripod radar dish",  # 精準飛彈組
    ],
    "cavalry": [
        "three identical tribal riders in furs mounted on shaggy horned beasts with red cloth harnesses",                                                            # 馭獸騎手
        "a wooden war chariot pulled by two horses, a driver and a spearman aboard, a plain red pennant streaming from the chariot rail",                            # 戰車騎兵
        "exactly two identical armored knights in plain bare steel helmets, each gripping one raised lance in the fist and the reins in the other hand, each mounted on one horse draped in a plain red cloth caparison, the horses wearing smooth plain rounded steel face plates, the pair riding alone across open bare ground",  # 重裝騎士團 (v3: v2 fixed the horns 4/4 but every seed then filled the empty canvas with an unattached object — floating shield, standing sword, rump finials, a curled hook — and one grew a third horse; fill both hands and the count positively and name the ground bare. v2: "barded horses" pulled fantasy horned/spiked chamfrons 4/4)
        "two identical hussar cavalrymen on galloping horses swinging curved sabers, plain red jackets with rows of brass braid cords, black fur busby hats",        # 驃騎兵
        "a heavy battle tank with a long cannon barrel, riveted armor plates, painted plain olive drab with a single white circle on the turret side",               # 坦克營
        "three identical sleek unmanned tracked combat vehicles with sensor domes and glowing blue lens eyes, gunmetal hulls each with a single white circle on the side",  # 無人戰車群
    ],
    "engineers": [
        "three identical tribal laborers in hide tunics carrying log beams and stone hammers, coils of rope over their shoulders, red cloth headbands",              # 修路隊
        "three identical builders in leather aprons, one laying stone blocks with a trowel, one carrying a wooden beam with a plain red cloth strip tied around its end, one swinging a big wooden mallet",  # 築城匠 (v2: "survey stake" rendered as a striped range-pole/rocket with a glowing tip on all 4 seeds — remove the freestanding-pole slot, move the red carrier onto the beam)
        "three identical sappers in iron kettle helmets and brown leather jerkins pushing a tall standing shield wall of rough wooden planks that rests on the ground on two cart wheels fixed at its lower edge, one carrying a pickaxe, one a bundle of sticks, plain red shoulder sashes",  # 攻城工兵 (v3: v2's "mounted on two cart wheels" let the wheel detach — one seed floated it unattached between figures, another threaded it onto the carried beam; seat the wall on the ground with the wheels at its lower edge. v2: "mantlet" is an unknown noun — every seed rendered a supply cart instead, and bare "sappers ... iron helmets" pulled WW1 uniforms; name the object's form and pin the era costume)
        "three identical soldiers in plain gray uniforms with red collar trim, one carrying a wooden plank bridge section, one a shovel, one a coil of wire",        # 工兵營
        "a yellow armored engineering vehicle with a bulldozer blade and a crane arm, two identical soldiers in olive uniforms and steel helmets walking beside it", # 機械化工兵
        "two identical soldiers in powered exo-frame suits with hydraulic arms, one carrying a folded bridge girder, one a heavy cutting torch with a glowing orange tip",  # 戰鬥工程隊
    ],
    "elite_forces": [
        "two identical royal guards in gilded bronze armor and tall red-plumed helmets holding ornate halberds, plain purple cloaks",                                # 禁衛軍
        "two identical temple knights in white surcoats over chainmail holding greatswords, each surcoat bearing a single golden tree emblem",                       # 聖殿武士
        "two identical grenadier soldiers in plain dark blue coats and tall black bearskin caps with red cords, one lighting the fuse of a round black grenade",     # 擲彈兵
        "two identical commandos in black tactical armor and night-vision goggles with glowing green lenses, compact rifles held ready",                             # 特種部隊
        "two identical heavy assault mechs with cockpit visors glowing red, oversized shoulder plates and rotary arm cannons, gunmetal and orange armor",            # 機甲突擊隊
    ],
    "artillery": [
        "a wooden ballista bolt-thrower on a sturdy frame with twisted rope springs, a giant red-fletched bolt loaded, two identical crew in leather tunics winching it",  # 弩砲
        "a squat bronze bombard cannon on a timber sled aimed upward, stone cannonballs stacked beside it, a crewman in a padded jacket holding a glowing red linstock",   # 射石砲
        "a field cannon with a bronze barrel resting on a two-wheeled carriage with large spoked wooden wheels, two identical gunners in plain dark blue uniforms each gripping a long bare wooden rammer staff with a cloth-wrapped head, a pyramid of black iron cannonballs",  # 野戰砲 (v3: v2's "plain unlit ... does not glow" NAMED the banned object and doubled it — one glowing tube became two, and the carriage reverted to e2's timber sled; describe the staff and the wheeled carriage positively, never mention light. v2: e2's "glowing red linstock" rode down as a glowing red cone, its padded jacket as a shearling flight jacket)
        "a tracked self-propelled howitzer with a long elevated gun barrel, painted plain olive drab with a single white circle on the hull side",                   # 自走砲
        "a futuristic tracked railgun platform with twin glowing blue magnetic rails and thick power cables, gunmetal armor with glowing blue conduits",             # 電磁砲
    ],
    "bomber": [
        "a red and white striped hot air balloon with a wicker basket, two identical crew dropping small round black bombs over the side",                           # 熱氣球轟炸隊
        "a heavy four-engine propeller bomber aircraft painted plain olive drab with a single white circle on the fuselage, bomb bay doors open with falling bombs", # 轟炸機聯隊
        "a black angular flying-wing stealth bomber with faint blue engine glow, bomb bay open with a single guided bomb dropping",                                  # 匿蹤轟炸機
    ],
    "holy_warriors": [
        "three identical zealot warriors in hooded white robes over scale armor swinging flanged maces, each robe bearing a single golden tree emblem",              # 聖戰士團
        "two identical musketeers in white coats each with a single golden tree emblem on the chest, beside a standard bearer holding a white banner painted with a single large golden tree",  # 神權火槍旅
        "a battle tank painted bone white with a single large golden tree emblem on the turret, golden tassels and votive ribbons hanging from the barrel",          # 狂信裝甲師
        "three identical hooded figures in white techno-robes with glowing golden circuit patterns, each holding up a tablet glowing with a single large golden tree symbol filling the screen",  # 聖戰網軍
    ],
    "privateers": [
        "three identical pirate mercenaries in weathered leather coats and head scarves with cutlasses and a boarding hook, one carrying a small chest overflowing with gold coins",  # 私掠傭兵團
        "three identical expedition soldiers in khaki uniforms and pith helmets with rifles and machetes, one carrying a brass-cornered chest, a plain red pennant on a backpack pole",  # 殖民遠征軍
        "three identical mercenary contractors in tan body armor and wraparound sunglasses with compact rifles, one holding a metal briefcase",                      # 戰地承包商
        "three identical figures in dark hooded jackets with glowing cyan visor glasses, gloved hands on glowing cyan holographic panels each showing a single large coin symbol, projected from wrist devices",  # 網路傭兵團
    ],
    "shield_wall": [
        "a row of tall rough wooden plank shields lashed together with rope into a standing wall, spear tips poking over the top, red cloth strips tied at the joints",  # 木盾牆
        "a tight wall of overlapping round bronze shields each embossed with a plain raised ring pattern, spears bristling between them",                            # 盾陣
        "a stone battlement wall segment with a crenellated top and arrow slits, an unbroken smooth masonry face and a clean level parapet line, a plain red pennant on a corner pole",  # 城垛 (v3: v2's "no arrows and no blades anywhere" NAMED the banned object and made it worse — 4 arrows became 7 projecting blades plus sparks; describe the intact surface positively and never name the weapon. v2: e2's "spears bristling between them" rode down as arrows driven through the stone heads-outward)
        "a chest-high wall of stacked burlap sandbags with wooden support posts, a rifle resting on the top edge",                                                   # 沙包工事
        "a squat gray concrete bunker with a narrow horizontal firing slit and iron rebar showing at the edges, sandbags piled at its base",                         # 混凝土碉堡
        "a segment of sleek composite armor barrier wall with hexagonal plating and glowing blue seam lights, deployable metal struts at its base",                  # 複合裝甲牆
    ],
    "trench": [
        "a single freestanding rounded mound of dug brown earth, a wide dark pit opening in its top with rows of sharpened wooden stakes pointing up from inside, a thin lattice of branches and leaves half covering the opening, loose dirt crumbs around the mound base",  # 陷坑 (v3: v2 cutaway bled to the frame edges and broke sprite isolation — package the pit as a freestanding mound)
        "a dug earth trench segment with a raised dirt parapet, wooden plank reinforcements and a wooden ladder inside",                                             # 壕溝
        "a water-filled moat segment with stone-lined banks, the water a flat calm horizontal surface seen from above at ground level, bare empty banks with no buildings and no animals, wooden stakes angled outward from the far bank",  # 護城壕 (v2: v1 rendered the water as an impossible vertical column in cutaway and kept breeding a micro-house on the bank — flatten the water to a horizontal plane, name the banks bare)
        "a deep trench segment with a sandbag parapet and wooden duckboards, coils of barbed wire strung on angled iron pickets in front",                           # 鐵絲網塹壕
        "a wide deep anti-tank ditch with sloped concrete walls, rows of gray concrete pyramid blocks lined up in front",                                            # 反戰車壕
        "a segment of automated defense line, a low armored wall with pop-up sentry gun turrets with glowing red sensor eyes and folding metal barrier plates",      # 自動化防線
    ],
    "anti_air": [
        "a slanted shelter roof of plain overlapping brown and tan dry raw hides on stout timber posts, several old spent arrows stuck upright in the hides, bare trampled earth below",  # 擋箭棚 (v3: v2's "arrows stuck in" kept splashing orange impact liquid on chain 84 (3 of that chain's 4 fails) — drain the energy: dry hides, old spent arrows. v2: v1's blank hide surfaces bred whimsy creatures/glyphs on every seed — name the hides plain, the earth bare)
        "a tall timber arrow tower with a roofed shooting platform and wooden hoardings, a red cloth strip tied to a corner post",                                   # 箭樓
        "a round stone defense tower with machicolations, its top an open flat circle of bare stone paving under clear open sky, a mounted ballista aimed skyward on it loaded with a plain wooden bolt",  # 城防塔 (v3: v2's "no roof and no tiles and no timber shelter" NAMED the banned object and the tiled roof came back on chain 84; describe the open stone top positively and never mention roofs. v2: e2's roofed shooting platform rode down as a tiled-roof timber pavilion, the bolt as glowing cyan energy)
        "an anti-aircraft flak cannon with a long barrel angled skyward on a cross-shaped mount, a ring gunsight, stacked shell crates beside it, painted plain olive drab",  # 高射砲
        "a tracked vehicle painted plain olive drab with a single white circle on the hull, carrying four white surface-to-air missiles on rails angled skyward",    # 防空飛彈
        "a futuristic laser interception turret, a cluster of lens barrels glowing blue on a rotating mount, a spinning radar dish on top, energy cables coiled at its base",  # 雷射攔截網
    ],
    "enemy_weak": [
        "a lone ragged raider in patchy furs swinging a crude stone axe, bone charms on a cord, charcoal war paint stripes",                                         # 弱 e1
        "a lone bandit in a dented bronze helmet and ragged dark tunic with a chipped short sword and a small wooden buckler",                                       # 弱 e2
        "a lone highwayman in a dark hood and patched leather jerkin aiming a light crossbow, a rusty dagger at his belt",                                           # 弱 e3
        "a lone ruffian in a ragged dark coat and a crumpled hat holding a worn flintlock pistol and a rusty knife",                                                 # 弱 e4
        "a lone thug in a ragged dark jacket and knit cap holding a crude submachine gun with a taped magazine",                                                     # 弱 e5
        "a lone looter in a ragged dark coat and a cracked orange visor holding a sparking makeshift energy pistol",                                                 # 弱 e6
    ],
    "enemy_mid": [
        "two identical fierce raiders in dark hides and bone-plate armor with jagged obsidian-edged clubs and hide shields",                                         # 中 e1
        "two identical mercenary raiders in dark iron scale armor with spiked maces, dented round shields each painted with a plain orange ring",                    # 中 e2
        "two identical brigand men-at-arms in blackened chainmail and dark kettle helmets with battleaxes, battered kite shields each painted with a plain orange ring",  # 中 e3
        "two identical renegade soldiers in ragged dark gray uniforms with bayoneted muskets, mismatched armor plates strapped over their chests",                   # 中 e4
        "two identical militia gunmen in dark body armor and balaclavas firing rifles, orange bandanas tied on their arms",                                          # 中 e5
        "two identical rogue soldiers in matte black powered vests with glowing orange visor slits and heavy energy rifles",                                         # 中 e6
    ],
    "enemy_hard": [
        "a hulking brute chieftain in heavy bone-and-hide armor swinging a massive stone maul, trophy horns mounted on his shoulders",                               # 硬 e1
        "a hulking champion in heavy dark bronze armor with a huge cleaver blade, a tower shield embossed with a plain raised ring pattern",                         # 硬 e2
        "a hulking black-armored knight with a spiked greathelm, a massive two-handed flail and a tattered dark cape",                                               # 硬 e3
        "a hulking soldier in a heavy dark iron cuirass carrying a hand-cranked multi-barrel gun, ammunition belts across his chest",                                # 硬 e4
        "a heavy dark battle tank with a rusted hull, welded scrap armor plates and a single orange stripe painted on the turret",                                   # 硬 e5
        "a towering black combat mech with glowing orange eye sensors, massive clawed arms and missile pods on its shoulders",                                       # 硬 e6
    ],
}

# lines that unlock later start their chain at this era (txt2img root there)
START_ERA = {"elite_forces": 2, "artillery": 2, "holy_warriors": 3, "privateers": 3, "bomber": 4}
