# phase3_bankdebt_manifest_sync.py — one-off manifest sync for the bank/debt_office redesign
# (human gate 2026-07-13: both lines rejected wholesale, re-rolled from e1 with researched
# iconography — cookbook §14). Idempotent; rerun after each wave to pick up new state cells.
#   1. Old-design candidates (pre-redesign stems) flip to rejected.
#   2. Every cell in phase3_building_chains.json for the two lines is appended as a candidate
#      if the manifest doesn't already carry its stem.
#   3. The superseded s571-574 era-5 cells get explicit per-cell reject reasons (§8 review).
# Run with any python3 from assets/pipeline/.
import json

from phase3_buildings_batch import START_ERA

MANIFEST = "manifest.jsonl"
STATE = "phase3_building_chains.json"
LINES = ("bank", "debt_office")
CHECKPOINT = "krea2_turbo_bf16@78bbf8f4"
LORAS = [["Krea2_Moebius_LoRA", 1.0]]
DATE = "2026-07-13"
OLD_DESIGN_REASON = ("design rejected at the 2026-07-13 human gate (bank: coin-string money "
                     "changer lineage; debt_office: statue-crutch offices); line re-rolled "
                     "from its start era with researched iconography")

# §8-rejected cells whose state entries were overwritten by later redo waves, so their
# generation params are pinned here: stem -> (line, prompt_key, reason). e5 wave 1 (s571-574,
# thermometer/glass-dome wording) failed 8/8; e5 wave 2 (s671-674, bell-jar/glass-tube wording)
# failed bank 4/4 + debt chain 73; e5 waves 3-4 failed bank chains on random contamination.
# e6 wave 1 (s571-574) failed bank 3/4 + debt chain 74.
E5_REJECTS = {
    "p3_bld_bank_e5_s571": ("bank", "w1", "ticker machine ballooned into a whimsical co-subject; ghost mouse figure and loose chairs"),
    "p3_bld_bank_e5_s572": ("bank", "w1", "traffic cone, game-emblem banner, ruin massing off the e4 structure"),
    "p3_bld_bank_e5_s573": ("bank", "w1", "pseudo-text sign panel on the facade; melted rock blobs on the balcony"),
    "p3_bld_bank_e5_s574": ("bank", "w1", "ghost teapot creature on the ribbon; ticker machine reads as a robot face"),
    "p3_bld_debt_office_e5_s571": ("debt_office", "w1", "gibberish numerals on the thermometer scale; red star finial; pseudo-text easel sign"),
    "p3_bld_debt_office_e5_s572": ("debt_office", "w1", "gibberish numerals on the thermometer scale"),
    "p3_bld_debt_office_e5_s573": ("debt_office", "w1", "legible invented signage 'GARIE BUILDING'"),
    "p3_bld_debt_office_e5_s574": ("debt_office", "w1", "gibberish numerals on the thermometer scale"),
    "p3_bld_bank_e5_s671": ("bank", "w2", "large ghost silhouette figure in the background (survives the freeze filter)"),
    "p3_bld_bank_e5_s672": ("bank", "w2", "giant ghost tentacle curling behind the building"),
    "p3_bld_bank_e5_s673": ("bank", "w2", "pseudo-letterform crest banner on a wall bracket; oversized decorative ribbons"),
    "p3_bld_bank_e5_s674": ("bank", "w2", "US national flags; gun-like object on the roofline"),
    "p3_bld_debt_office_e5_s673": ("debt_office", "w2", "vein-like tangled pipes below the tube; small creature object on the battlements"),
    "p3_bld_bank_e5_s771": ("bank", "w3", "Christian cross finial on the roof gable (religion carries the golden-tree motif); odd lectern-figure vignette at the entrance"),
    "p3_bld_bank_e5_s772": ("bank", "w3", "giant surreal flower stalk growing up the facade"),
    "p3_bld_bank_e5_s774": ("bank", "w3", "legible invented vertical signage 'GAHR'"),
    "p3_bld_bank_e5_s874": ("bank", "w3", "gold pseudo-letterforms on a purple bracket banner"),
    "p3_bld_bank_e6_s571": ("bank", "e6", "green horse-head logo on a screen post; letterform 'H' badge on a mini house-bot; floating orange panel; massing collapsed into a machine-yard diorama"),
    "p3_bld_bank_e6_s572": ("bank", "e6", "rainbow-striped flag on the roof (real-world flag pattern); storefront awning annex grafted onto the base"),
    "p3_bld_bank_e6_s574": ("bank", "e6", "boxy robot mascot at the entrance (ghost object)"),
    "p3_bld_debt_office_e6_s574": ("debt_office", "e6", "miniature city model grafted onto the plaza corner (ghost object, silhouette-breaking)"),
    "p3_bld_bank_e6_s671": ("bank", "e6", "miniature pagoda house with trees grafted onto the plaza (e5 side-annex morphing into a companion building)"),
    "p3_bld_bank_e6_s672": ("bank", "e6", "currency-glyph shield sign at the entrance; brick house annex with red flag grafted onto the tower"),
    "p3_bld_bank_e6_s674": ("bank", "e6", "blue star flag (national-flag pattern); neon glyph shop sign annex; teal squid-shaped ghost object"),
    "p3_bld_bank_e6_s774": ("bank", "e6b", "crumpled humanoid form lying on the plaza edge (ghost object)"),
}
E5_OLD_PROMPTS = {
    ("bank", "w1"): "a stone high-rise tower on a columned base, a brass ticker-tape machine "
                    "under a glass dome by the entrance spilling a blank curling paper ribbon",
    ("debt_office", "w1"): "a stone office building with a queue of civilians at a brass-barred "
                           "counter window, a large thermometer-style board with a rising red "
                           "column and plain tick marks mounted on the facade",
    ("bank", "w2"): "a stone bank tower with rows of tall windows rising above a columned base, "
                    "a small brass ticker-tape machine under a glass bell jar beside the "
                    "entrance, a short blank paper ribbon curling from it",
    ("debt_office", "w2"): "a stone office building with a queue of civilians at a brass-barred "
                           "counter window, a tall glass tube of glowing red liquid rising up "
                           "the facade in a plain dark wooden frame",
    ("bank", "w3"): "a stone bank tower with rows of tall windows rising above a columned base, "
                    "a brass ticker-tape machine on a pedestal visible in the lobby through the "
                    "arched entrance window, plain golden pennants on the roof",
    ("bank", "e6"): "a curved glass tower wrapped by a glowing band of abstract candlestick "
                    "chart bars, server racks with blinking lights visible through the glass",
    ("bank", "e6b"): "a curved glass tower wrapped by a glowing band of abstract candlestick "
                     "chart bars, server racks with blinking lights visible through the glass, "
                     "a plain golden pennant on the roof, standing alone on a wide empty stone "
                     "plaza",
    ("debt_office", "e6"): "a glass office tower with a strict stone and copper grid facade, a "
                           "golden tree emblem above the entrance, visible floors of suited "
                           "officials at desks",
}
E5_SUFFIX = ", game building sprite, side view, centered, isolated on a plain light gray background"


def entry(line: str, era: int, stem: str, seed: int, prompt: str, source: str | None,
          status: str = "candidate", reject_reason: str | None = None) -> dict:
    e = {
        "id": stem,
        "file": f"~/ComfyUI-Shared/output/phase3-buildings/{stem}_00001_.png",
        "class": "building-candidate",
        "subject": f"building_{line}_era{era}",
        "prompt": prompt,
        "negative": None,
        "seed": seed,
        "checkpoint": CHECKPOINT,
        "loras": LORAS,
        "workflow": "workflows/krea2_lora_img2img.json" if source else "workflows/krea2_lora_txt2img.json",
        "lineage": {"source": source, "denoise": 0.55} if source else None,
        "post": None,
        "status": status,
        "date": DATE,
    }
    if reject_reason:
        e["reject_reason"] = reject_reason
    return e


def main() -> None:
    with open(STATE) as f:
        state = json.load(f)

    new_stems = {c["stem"] for line in LINES for chain in state[line].values() for c in chain.values()}
    new_stems |= set(E5_REJECTS)

    entries, seen = [], set()
    with open(MANIFEST) as f:
        for raw in f:
            e = json.loads(raw)
            if (any(e["id"].startswith(f"p3_bld_{line}_") for line in LINES)
                    and e["id"] not in new_stems and e["status"] == "candidate"):
                e["status"] = "rejected"
                e["reject_reason"] = OLD_DESIGN_REASON
            entries.append(e)
            seen.add(e["id"])

    added = 0
    for line in LINES:
        for chain, cells in state[line].items():
            for era_s, cell in sorted(cells.items(), key=lambda kv: int(kv[0])):
                era = int(era_s)
                if cell["stem"] in seen:
                    continue
                source = None
                if era > START_ERA.get(line, 1):
                    source = cells[str(era - 1)]["stem"] if str(era - 1) in cells else None
                entries.append(entry(line, era, cell["stem"], cell["seed"], cell["prompt"], source))
                seen.add(cell["stem"])
                added += 1

    for stem, (line, wave, reason) in E5_REJECTS.items():
        if stem in seen:
            continue
        seed = int(stem.rsplit("_s", 1)[1])
        era = int(stem.rsplit("_e", 1)[1].split("_")[0])
        source = state[line][str(seed % 100)][str(era - 1)]["stem"]
        entries.append(entry(line, era, stem, seed, E5_OLD_PROMPTS[(line, wave)] + E5_SUFFIX,
                             source, status="rejected", reject_reason=reason))
        seen.add(stem)
        added += 1

    flipped = sum(1 for e in entries if e.get("reject_reason") == OLD_DESIGN_REASON)
    with open(MANIFEST, "w") as f:
        f.write("\n".join(json.dumps(e, ensure_ascii=False) for e in entries) + "\n")
    print(f"old-design entries rejected: {flipped}; new entries appended: {added}; total: {len(entries)}")


if __name__ == "__main__":
    main()
