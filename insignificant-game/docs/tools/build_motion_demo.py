#!/usr/bin/env python3
"""Embed the exploratory top-down sprites into explore-topdown-motion-demo.html.

The demo is deliberately a single self-contained file: sprites live in it as base64 data
URIs so it can be double-clicked from anywhere. Relative paths would add a silent-404 mode
the moment the HTML travels. This script is what makes that practical: it keys the plain
grey render background to transparent, trims, downscales, quantises, and rewrites ONLY the
marked sprite block plus the footer credits, so hand-edited JS and CSS survive re-runs.

    python3 docs/tools/build_motion_demo.py            # from insignificant-game/
    python3 docs/tools/build_motion_demo.py --dry-run   # report, write nothing

Input  : assets/exploration/topdown-demo/<class>_e<era>.png  (exploratory raws, not pipeline
         assets; generator prefixes like exp_td2_simple_infantry_e1.png are normalised)
Output : docs/explore-topdown-motion-demo.html, between the @SPRITES / @CREDITS markers.
"""
from __future__ import annotations

import argparse
import base64
import io
import os
import re
import sys

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
except ImportError:
    sys.exit("Pillow is required: python3 -m pip install Pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC_DIR = os.path.join(GAME, "assets", "exploration", "topdown-demo")
HTML = os.path.join(GAME, "docs", "explore-topdown-motion-demo.html")

SPRITES_BEGIN, SPRITES_END = "/* @SPRITES-BEGIN */", "/* @SPRITES-END */"
CREDITS_BEGIN, CREDITS_END = "<!-- @CREDITS-BEGIN -->", "<!-- @CREDITS-END -->"

# Must stay in step with CLASSES in the demo and with core/data/cards.gd era_names.
ERAS = {
    "infantry": [1, 2, 3, 4, 5, 6],
    "archers": [1, 2, 3, 4, 5, 6],
    "cavalry": [1, 2, 3, 4, 5, 6],
    "engineers": [1, 2, 3, 4, 5, 6],
    "elite_forces": [2, 3, 4, 5, 6],
    "artillery": [3, 4, 5, 6],
    "bomber": [4, 5, 6],
    "holy_warriors": [4],
    "privateers": [3, 4, 5],
    "shield_wall": [1, 2, 3, 4, 5, 6],
    "anti_air": [1, 2, 3, 4, 5, 6],
}
# longest first so elite_forces never matches as 'forces' inside another stem
CLASSES = sorted(ERAS, key=len, reverse=True)

# Flying weapons. These have no era: one sprite per ammo type, keyed proj_<name>, mapped onto
# classes/eras by the demo's AMMO table. A missing one is a warning, not an error: the demo
# falls back to drawing a plain tracer line.
PROJECTILES = ["stone", "arrow", "bolt", "bullet", "missile", "cannonball", "shell", "bomb"]

# Progressive tightening if the embedded file overshoots its budget.
LADDER = [(256, 128), (224, 96), (192, 64), (160, 48)]
WARN_BYTES = int(4.5 * 1024 * 1024)
STOP_BYTES = 6 * 1024 * 1024

KEY_THRESH = 34       # flood-fill tolerance when keying the render background
SEED_THRESH = 20      # max per-channel gap from the reference before a seed is refused
POCKET_THRESH = 5     # ditto for seeding an enclosed pocket: far tighter, because a pocket IS
                      # the render background, while the subject's own greys only resemble it
RING_DARK = 120       # a pocket is sealed by ligne-claire outline, so its rim reads this dark
RING_SHARE = 0.25     # ...over at least this share of the rim
SENTINEL = (255, 0, 255)


def _bg_reference(rgb: Image.Image) -> tuple[int, int, int]:
    """Median colour of the frame border: the flat render background."""
    w, h = rgb.size
    px = [rgb.getpixel((x, y)) for x in range(0, w, 8) for y in (0, h - 1)]
    px += [rgb.getpixel((x, y)) for y in range(0, h, 8) for x in (0, w - 1)]
    px.sort(key=sum)
    return px[len(px) // 2]


def _worst_channel(a: Image.Image, b: Image.Image) -> Image.Image:
    r, g, bl = ImageChops.difference(a, b).split()
    return ImageChops.lighter(ImageChops.lighter(r, g), bl)


def _near_bg(rgb: Image.Image, ref: tuple[int, int, int], thresh: int) -> Image.Image:
    """Mask of pixels within `thresh` of `ref` on every channel."""
    worst = _worst_channel(rgb, Image.new("RGB", rgb.size, ref))
    return worst.point(lambda v: 255 if v <= thresh else 0)


def _keyed(rgb: Image.Image) -> Image.Image:
    """Mask of the pixels a fill has already claimed."""
    worst = _worst_channel(rgb, Image.new("RGB", rgb.size, SENTINEL))
    return worst.point(lambda v: 255 if v == 0 else 0)


def _sealed_by_linework(gray: Image.Image, region: Image.Image) -> bool:
    """Does the subject's dark outline run around this region?

    The one test that separates a pocket of backdrop from a pale fill of the subject's own
    (a grey hull, a white surcoat), which by colour alone are indistinguishable from it. A
    pocket is walled in by ligne-claire outline; a highlight on a hull just fades into more hull.
    """
    rim = ImageChops.subtract(region.filter(ImageFilter.MaxFilter(5)), region)
    hist = gray.histogram(rim)
    total = sum(hist)
    return total > 0 and sum(hist[:RING_DARK]) >= RING_SHARE * total


def scan() -> dict[str, str]:
    """Map <class>_e<era> -> path, normalising any generator prefix. Unmapped files fail."""
    if not os.path.isdir(SRC_DIR):
        sys.exit(f"no sprite directory: {SRC_DIR}")
    found: dict[str, str] = {}
    unmapped: list[str] = []
    for name in sorted(os.listdir(SRC_DIR)):
        if not name.lower().endswith(".png"):
            continue
        stem = name[:-4]
        key = None
        if stem.startswith("proj_"):
            if stem[5:] not in PROJECTILES:
                unmapped.append(name)
                continue
            found[stem] = os.path.join(SRC_DIR, name)
            continue
        for cls in CLASSES:
            m = re.search(rf"{re.escape(cls)}_e(\d)$", stem)
            if m:
                key = f"{cls}_e{m.group(1)}"
                break
        if key is None:
            unmapped.append(name)
            continue
        if key in found:
            sys.exit(f"two files map to {key}: {os.path.basename(found[key])} and {name}")
        found[key] = os.path.join(SRC_DIR, name)
    if unmapped:
        sys.exit("unmapped sprite files (rename or remove them):\n  " + "\n  ".join(unmapped))
    return found


def resolve(found: dict[str, str]) -> tuple[dict[str, str], list[tuple[str, str]]]:
    """Fill missing class+era combos from the nearest era of the same class."""
    have_classes = {k.rsplit("_e", 1)[0] for k in found}
    missing_classes = [c for c in ERAS if c not in have_classes]
    if missing_classes:
        sys.exit("no sprite at all for: " + ", ".join(missing_classes)
                 + "\n  every class needs at least one era; generate them or shrink the demo roster.")
    picked: dict[str, str] = {}
    subs: list[tuple[str, str]] = []
    absent_proj = []
    for name in PROJECTILES:
        key = f"proj_{name}"
        if key in found:
            picked[key] = found[key]
        else:
            absent_proj.append(key)
    if absent_proj:
        print("WARNING: no sprite for these flying weapons, the demo will draw a plain tracer "
              "line instead: " + ", ".join(absent_proj))
    for cls, eras in ERAS.items():
        for era in eras:
            key = f"{cls}_e{era}"
            if key in found:
                picked[key] = found[key]
                continue
            alt = None
            for e in range(era - 1, 0, -1):          # nearest LOWER era first
                if f"{cls}_e{e}" in found:
                    alt = f"{cls}_e{e}"
                    break
            if alt is None:
                for e in range(era + 1, 7):          # then nearest higher
                    if f"{cls}_e{e}" in found:
                        alt = f"{cls}_e{e}"
                        break
            if alt is None:
                sys.exit(f"cannot fill {key} and no other era of {cls} exists")
            picked[key] = found[alt]
            subs.append((key, alt))
    return picked, subs


def key_background(im: Image.Image) -> Image.Image:
    """Key the plain light-grey render background to transparent.

    Flood-fills rather than matching a colour globally, so light interior fills (white
    waistcoats, pale hulls) are never punched through. Two passes: outward-in from the frame
    edges, then one fill per enclosed pocket of background the first pass cannot reach.
    """
    rgb = im.convert("RGB")
    w, h = rgb.size
    ref = _bg_reference(rgb)
    seeds = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
             (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    for seed in seeds:
        px = rgb.getpixel(seed)
        # A subject that runs off the frame (the era-4 airship spans the full width) puts a
        # mid-edge seed on the subject itself, where a fill would eat it. Refuse those.
        if px == SENTINEL or max(abs(a - b) for a, b in zip(px, ref)) > SEED_THRESH:
            continue
        ImageDraw.floodfill(rgb, seed, SENTINEL, thresh=KEY_THRESH)

    # Background sealed off by the subject (between an arm and a torso, inside the curve of a
    # bow) is unreachable from the frame edge and survives the pass above as a grey slab. Fill
    # each such pocket separately. Colour alone cannot authorise the fill: gun metal and pale
    # hulls carry patches that match the backdrop exactly, and punching those out is worse than
    # the slab. So each candidate is filled on a scratch copy and only committed if the outline
    # test agrees. MinFilter drops lone matching pixels, which are never pockets.
    gray = rgb.convert("L")
    candidates = _near_bg(rgb, ref, POCKET_THRESH).filter(ImageFilter.MinFilter(3)).tobytes()
    rejected = Image.new("L", rgb.size, 0)
    pos = 0
    while True:
        i = candidates.find(b"\xff", pos)
        if i < 0:
            break
        pos = i + 1
        xy = (i % w, i // w)
        # already swallowed by an earlier fill, or inside a pocket the outline test turned down
        if rgb.getpixel(xy) == SENTINEL or rejected.getpixel(xy):
            continue
        scratch = rgb.copy()
        ImageDraw.floodfill(scratch, xy, SENTINEL, thresh=KEY_THRESH)
        region = ImageChops.subtract(_keyed(scratch), _keyed(rgb))
        if _sealed_by_linework(gray, region):
            rgb.paste(SENTINEL, (0, 0), region)
        else:
            rejected.paste(255, (0, 0), region)

    # alpha = 0 exactly where the fill landed. Max-of-channels keeps the test exact
    # (a per-pixel Python loop would be ~1M iterations per sprite).
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, SENTINEL))
    r, g, b = diff.split()
    filled = ImageChops.lighter(ImageChops.lighter(r, g), b)
    alpha = filled.point(lambda v: 0 if v == 0 else 255)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.6))   # soften the cut edge
    out = im.convert("RGBA")
    out.putalpha(alpha)
    bbox = out.getbbox()
    return out.crop(bbox) if bbox else out


def encode(path: str, max_dim: int, colors: int, cache: dict) -> str:
    ck = (path, max_dim, colors)
    if ck in cache:
        return cache[ck]
    with Image.open(path) as raw:
        im = key_background(raw)
    scale = max_dim / max(im.size)
    if scale < 1:
        im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))),
                       Image.LANCZOS)
    # FASTOCTREE is the quantiser that keeps the alpha channel
    im = im.quantize(colors=colors, method=Image.FASTOCTREE)
    buf = io.BytesIO()
    im.save(buf, format="PNG", optimize=True)
    uri = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
    cache[ck] = uri
    return uri


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="report only, do not write the HTML")
    args = ap.parse_args()

    found = scan()
    picked, subs = resolve(found)
    print(f"sprites found: {len(found)} · keys needed: {len(picked)}")

    if subs:
        print("\nWARNING: era substitutions (a real render is missing for these)")
        print(f"  {'key':22} {'rendered from':22}")
        for key, alt in subs:
            print(f"  {key:22} {alt:22}")
        if any(k.startswith("holy_warriors") for k, _ in subs):
            print("  NOTE: holy_warriors exists only at era 4, so it has no era to fall back on.")
        print()

    with open(HTML, encoding="utf-8") as f:
        html = f.read()
    for marker in (SPRITES_BEGIN, SPRITES_END, CREDITS_BEGIN, CREDITS_END):
        if marker not in html:
            sys.exit(f"marker missing from the HTML: {marker}")

    cache: dict = {}
    chosen = None
    for max_dim, colors in LADDER:
        entries = {k: encode(picked[k], max_dim, colors, cache) for k in sorted(picked)}
        block = (SPRITES_BEGIN + "\n// generated by docs/tools/build_motion_demo.py, do not "
                 f"hand-edit\n// {len(entries)} sprites, {max_dim}px max side, {colors} colours\n"
                 "const SPRITES = {\n"
                 + "".join(f"  {k!r}: {v!r},\n".replace("'", '"') for k, v in entries.items())
                 + "};\n"
                 # The page's asset table names its own sources. Emitted rather than derived from
                 # the key, because resolve() may fill a missing era from a neighbouring one, and
                 # a table that guessed <key>.png would then name a file that does not exist.
                 + "const SPRITE_SRC = {\n"
                 + "".join(f'  "{k}": "{os.path.basename(picked[k])}",\n' for k in sorted(entries))
                 + "};\n" + SPRITES_END)
        credits = (CREDITS_BEGIN + "\n    sprites: "
                   f"{len(found)} exploratory top-down raws "
                   f"({max_dim}px, {colors}-colour, background keyed to transparent) from "
                   "assets/exploration/topdown-demo/ · raws only, never pipeline assets.\n    "
                   + CREDITS_END)
        out = re.sub(re.escape(SPRITES_BEGIN) + r".*?" + re.escape(SPRITES_END), lambda _: block,
                     html, flags=re.S)
        out = re.sub(re.escape(CREDITS_BEGIN) + r".*?" + re.escape(CREDITS_END),
                     lambda _: credits, out, flags=re.S)
        size = len(out.encode("utf-8"))
        note = "ok" if size <= WARN_BYTES else ("over the 4.5MB warn line" if size <= STOP_BYTES
                                                else "over the 6MB hard stop")
        print(f"  {max_dim}px / {colors} colours -> {size/1024/1024:.2f} MB ({note})")
        chosen = (out, size, max_dim, colors)
        if size <= WARN_BYTES:
            break

    out, size, max_dim, colors = chosen
    if size > STOP_BYTES:
        sys.exit(f"\nHARD STOP: {size/1024/1024:.2f} MB even at the tightest setting. Drop era "
                 "variants (one sprite per class) rather than switching to relative paths.")
    if size > WARN_BYTES:
        print(f"\nWARNING: {size/1024/1024:.2f} MB exceeds the 4.5MB budget but is under the "
              "6MB hard stop.")

    if args.dry_run:
        print("\ndry run: nothing written")
        return
    with open(HTML, "w", encoding="utf-8") as f:
        f.write(out)
    print(f"\nwrote {HTML}")
    print(f"final: {size/1024/1024:.2f} MB · {len(picked)} sprite keys "
          f"· {max_dim}px / {colors} colours")


if __name__ == "__main__":
    main()
