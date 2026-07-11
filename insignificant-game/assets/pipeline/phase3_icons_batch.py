# phase3_icons_batch.py — Phase 3 class 1: UI icon glyphs (cookbook §7), generated under the
# locked style bible §2-§3 and reviewed composited into the frozen plate (style bible §9).
# Groups follow inventory.md "UI icons"; run one group per invocation, e.g.
# `phase3_icons_batch.py core`. Glyph subjects below are proposals — the human judges them on
# the contact sheet like any candidate. Run with the ComfyUI venv python from assets/pipeline/.
import subprocess
import sys

SEEDS = [61, 62, 63]
WORKFLOW = "workflows/krea2_lora_txt2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
SUFFIX = ", bold dark outline, centered, plain light gray background"

# group -> {icon id suffix: subject core (style bible §3 icon row; suffix appended)}
# Subjects avoid prominent flat blank surfaces (crates, folders, chip faces, box fronts) where
# the model prints invented text — the sweep batch's only artifact class (cookbook §14).
GROUPS = {
    "core": {
        "money": "a single gold coin with an embossed crown, game currency icon",
        "population": "two standing villagers side by side, game population icon",
        "bp": "a wooden mallet crossed with a stone chisel, game build points icon",
        "tech": "a large brass cogwheel, game technology icon",
        "culture": "a classical golden lyre, game culture icon",
        "happiness": "a radiant smiling sun, game happiness icon",
        "debt": "a stack of gold coins with a jagged crack through it, game debt icon",
        # debt alternates: v1 renders as a plain coin stack (reads as wealth, collides with money)
        "debt2": "a single gold coin broken in two halves with a jagged crack between them, game debt icon",
        "debt3": "a leather money pouch turned inside out, empty and drooping, game debt icon",
        "interest": "an hourglass filled with falling gold coins, game interest icon",
        "unrest": "a raised clenched fist, game unrest icon",
        "power": "a shield emblazoned with a five-pointed star, game power icon",
    },
    # core gate re-rolls (human feedback): population must not read as a male/female pair;
    # unrest came out monochrome and must carry color like the other glyphs.
    "core_fix": {
        "population2": "two identical villagers in matching hooded tunics standing side by side, game population icon",
        "population3": "a huddled group of three identical hooded villagers, game population icon",
        "unrest2": "a raised clenched fist in a torn red sleeve, game unrest icon",
        "unrest3": "a raised clenched fist gripping a burning torch with orange flames, game unrest icon",
    },
    # all subjects below carry an inherently colored element and avoid bare-metal/mono objects
    # (cookbook §14 core_fix learning); ids match inventory.md so subject = icon_<key>.
    "battle": {
        "attack": "a single sword with a golden hilt pointing upward, game attack icon",
        "hp": "a bold red heart shape, game health icon",
        "military_cost": "a gold coin stamped with a crossed-swords mark, game military cost icon",
    },
    "card_classes": {
        "class_personnel": "a bronze soldier helmet with a red plume, game personnel card class icon",
        "class_mechanical": "a wooden siege catapult, game mechanical card class icon",
        "class_fortification": "a stone castle tower with a red banner on top, game fortification card class icon",
        "class_skill": "an unrolled parchment scroll with a red wax seal, game skill card class icon",
    },
    "regions": {
        "region_livelihood": "a sheaf of golden wheat tied with a rope, game livelihood region icon",
        "region_academic": "an open book with a red bookmark ribbon, game academic region icon",
        "region_military": "a red war banner on a wooden pole, game military region icon",
        "region_culture": "a pair of theater masks, one gold and one purple, game culture region icon",
        "region_finance": "a neat stack of gold coins, game finance region icon",
    },
    "policy_themes": {
        "theme_power": "a golden royal scepter, game power policy icon",
        "theme_tech": "a glowing warm yellow lightbulb, game technology policy icon",
        "theme_culture": "a wooden artist palette with colorful paint blobs, game culture policy icon",
        "theme_religion": "two hands clasped in prayer with golden light rays behind, game religion policy icon",
        "theme_exploration": "a brass compass with a red needle, game exploration policy icon",
        "theme_recon": "a brass spyglass, game reconnaissance policy icon",
    },
    "policy_nodes": {
        "policy_centralization": "a golden throne, game centralization policy icon",
        "policy_bureaucracy": "a stack of parchment documents with a red wax stamp, game bureaucracy policy icon",
        "policy_secret_police": "a brass keyhole with a watching eye behind it, game secret police policy icon",
        "policy_cultural_revolution": "a raised red book, game cultural revolution policy icon",
        "policy_enlightened_absolutism": "a golden crown radiating warm light rays, game enlightened absolutism policy icon",
        "policy_writing_calendar": "a clay tablet with carved glyphs and a golden sun symbol, game writing and calendar policy icon",
        "policy_secularization": "a golden scale of justice, game secularization policy icon",
        "policy_patent_system": "a parchment certificate with a golden ribbon seal, game patent system policy icon",
        "policy_moon_race": "a red and white rocket flying toward a crescent moon, game moon race policy icon",
        "policy_space_station": "a space station with blue solar panels, game space station policy icon",
        "policy_ancestor_worship": "a stone ancestral altar with burning red incense sticks, game ancestor worship policy icon",
        "policy_state_religion": "a temple with a golden dome and a small flag on top, game state religion policy icon",
        "policy_theocracy": "a golden crown resting on a temple altar, game theocracy policy icon",
        "policy_holy_war": "a sword with golden flames along the blade, game holy war policy icon",
        "policy_hundred_schools": "several colorful overlapping speech bubbles, game hundred schools policy icon",
        "policy_mass_media": "a red and white radio tower broadcasting signal waves, game mass media policy icon",
        "policy_cultural_export": "a wooden shipping crate stamped with a purple theater mask, game cultural export policy icon",
        "policy_great_voyage": "a sailing ship with white sails on blue waves, game great voyage policy icon",
        "policy_world_map": "an unrolled parchment world map with blue oceans, game world map policy icon",
        "policy_world_expo": "a grand glass exhibition pavilion with colorful flags, game world expo policy icon",
        "policy_scout_camp": "a small campfire beside a brown tent, game scout camp policy icon",
        "policy_political_marriage": "two golden rings interlinked with a red ribbon, game political marriage policy icon",
        "policy_intelligence_agency": "a brown dossier folder stamped with a red seal, game intelligence agency policy icon",
        "policy_satellite_surveillance": "a satellite with blue solar panels beaming a signal downward, game satellite surveillance policy icon",
    },
    "legacies": {
        "legacy_religious_dogma": "a thick closed tome with a golden lock, game religious dogma legacy icon",
        "legacy_rational_spirit": "a glass laboratory flask with blue liquid, game rational spirit legacy icon",
        "legacy_critical_spirit": "a quill crossing out text with red ink on parchment, game critical spirit legacy icon",
        "legacy_rock_spirit": "an electric guitar with a red body, game rock spirit legacy icon",
        "legacy_democratic_spirit": "a ballot slip dropping into a wooden ballot box, game democratic spirit legacy icon",
        "legacy_melting_pot": "a bronze crucible pouring golden molten metal, game melting pot legacy icon",
        "legacy_martial_law": "a road barrier with red and white stripes, game martial law legacy icon",
    },
    "map_nodes": {
        "map_battle": "two crossed swords with golden hilts, game battle map node icon",
        "map_unknown": "a large purple question mark, game unknown map node icon",
        "map_war": "a globe wrapped in red flames, game world war map node icon",
        "map_skip": "a golden arrow arcing over a small hill, game skip map node icon",
    },
    "opportunities": {
        "opp_merchant": "a brown leather merchant satchel overflowing with gold coins, game merchant opportunity icon",
        "opp_refugee": "a cloth bundle tied to a wooden walking stick, game refugee opportunity icon",
        "opp_disaster": "a red lightning bolt striking cracked ground, game disaster opportunity icon",
        "opp_treasure": "an open wooden treasure chest full of gold, game treasure opportunity icon",
    },
    "eras": {
        "era1": "a round thatched hut, game tribal era icon",
        "era2": "a white marble column with a golden capital, game classical era icon",
        "era3": "a stained glass window with colorful panes, game faith era icon",
        "era4": "a brick factory with smoking chimneys, game industrial era icon",
        "era5": "a cluster of blue glass skyscrapers, game modern era icon",
        "era6": "a blue glowing microchip with circuit lines, game information era icon",
    },
    "democracy": {
        "fund": "a hand dropping gold coins into a wooden ballot box, game campaign funding icon",
    },
    # sweep-gate re-rolls: flat surfaces (crates, folders, chips) invite invented printed text,
    # and "grand pavilion" pulled full scene compositions — v2 subjects remove the invitation.
    "sweep_fix": {
        "policy_world_expo2": "a glass and iron exhibition dome building with a colorful flag on top, game world expo policy icon",
        "policy_intelligence_agency2": "a brown dossier folder tied with red string, game intelligence agency policy icon",
        "era6v2": "a glowing blue computer microchip covered in glowing circuit traces, game information era icon",
        "policy_cultural_revolution2": "a raised red book with a golden star on its cover, game cultural revolution policy icon",
        "legacy_critical_spirit2": "a quill crossing out unreadable scribbled lines with red ink on parchment, game critical spirit legacy icon",
    },
    # era6 second re-roll: v2 still printed "era" on the chip face 3/3 — the word leaks from the
    # framing suffix itself and a bare chip center begs for part-number text. v3 occupies the
    # center with an object; v4 swaps the subject away from chips entirely.
    "era6_fix": {
        "era6v3": "a glowing blue computer microchip with a hexagonal crystal core at its center, game digital age icon",
        "era6v4": "a globe surrounded by a glowing blue network of connected nodes, game digital age icon",
    },
    # sweep-gate pick re-rolls (human): religion stays non-specific in this game — the neutral
    # religious motif is a golden tree (dogma tome cover, era-3 stained glass); democratic_spirit
    # should read as an explicit marked ballot, not a plain lined sheet.
    "picks_fix": {
        "legacy_religious_dogma2": "a thick closed tome with a golden tree emblem on its cover and a golden lock, game religious dogma legacy icon",
        "legacy_democratic_spirit2": "a ballot paper marked with a bold red check mark, half inserted into the slot of a wooden ballot box, game democratic spirit legacy icon",
        "era3v2": "a stained glass window with colorful panes depicting a golden tree, game faith era icon",
    },
}


def main() -> None:
    wanted = sys.argv[1:] or ["core"]
    for group in wanted:
        for icon, core in GROUPS[group].items():
            for seed in SEEDS:
                job_id = f"p3_icon_{icon}_s{seed}"
                cmd = [sys.executable, "comfy_run.py", WORKFLOW,
                       "--seed", str(seed), "--prompt", core + SUFFIX,
                       "--width", "1024", "--height", "1024",
                       "--prefix", f"phase3-icons/{job_id}", *LORA_ARGS]
                for attempt in (1, 2):
                    print(f"=== {job_id}" + (" (retry)" if attempt == 2 else ""), flush=True)
                    if subprocess.run(cmd).returncode == 0:
                        break
                else:
                    raise SystemExit(f"{job_id} failed twice, aborting the batch")


if __name__ == "__main__":
    main()
