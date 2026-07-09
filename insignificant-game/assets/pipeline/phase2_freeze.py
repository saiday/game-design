# phase2_freeze.py — freeze the human-picked Phase 2 templates (cookbook §6-§7) into
# assets/approved/ui/. One-time processing, params tuned on the picked raws:
# background/shadow keying (border flood fill), card-frame window keying, faint-ink
# cleanup on the card-frame parchment (the once-allowed Phase 2 manual cleanup),
# tight crop, and measurement of the content rects / 9-slice margins printed for the
# style bible. Run with the ComfyUI venv python from assets/pipeline/.
import os

import numpy as np
from PIL import Image, ImageFilter

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase2-templates")
DST = "../approved/ui"

# template -> (picked stem, border-flood tolerance; button 95 eats its baked drop shadow)
PICKS = {
    "card_frame": ("p2_card_frame_s53", 60),
    "panel": ("p2_panel_s51", 60),
    "button": ("p2_button_s54", 95),
    "icon_plate": ("p2_icon_plate_s53", 60),
    "divider": ("p2_divider2_s55", 60),  # v2 re-roll winner
}


def flood(mask: np.ndarray, seed: np.ndarray) -> np.ndarray:
    grown = seed & mask
    while True:
        nxt = grown.copy()
        nxt[1:, :] |= grown[:-1, :]
        nxt[:-1, :] |= grown[1:, :]
        nxt[:, 1:] |= grown[:, :-1]
        nxt[:, :-1] |= grown[:, 1:]
        nxt &= mask
        if (nxt == grown).all():
            return grown
        grown = nxt


def border_seed(shape: tuple) -> np.ndarray:
    s = np.zeros(shape, dtype=bool)
    s[0, :], s[-1, :], s[:, 0], s[:, -1] = True, True, True, True
    return s


def point_seed(shape: tuple, y: int, x: int) -> np.ndarray:
    s = np.zeros(shape, dtype=bool)
    s[y, x] = True
    return s


def clean_parchment(rgb: np.ndarray, box: tuple) -> np.ndarray:
    """Remove faint aged-ink scribbles: replace pixels notably darker than the local
    median with the median (detection dilated 2px), inside the text-panel box only."""
    x0, y0, x1, y1 = box
    region = rgb[y0:y1, x0:x1]
    med = np.asarray(Image.fromarray(region).filter(ImageFilter.MedianFilter(15)), dtype=int)
    dark = (med.sum(axis=2) - region.astype(int).sum(axis=2)) > 30
    for _ in range(2):  # dilate
        grow = dark.copy()
        grow[1:, :] |= dark[:-1, :]
        grow[:-1, :] |= dark[1:, :]
        grow[:, 1:] |= dark[:, :-1]
        grow[:, :-1] |= dark[:, 1:]
        dark = grow
    region[dark] = med.astype(np.uint8)[dark]
    print(f"  parchment cleanup: {int(dark.sum())} px inpainted in {box}")
    return rgb


def nine_slice_margins(rgba: np.ndarray) -> tuple:
    """Margins (left, top, right, bottom) = extent of the corner/end ornaments: the
    outermost column/row whose profile still differs from the center column/row profile
    (the stretchable mid-edge region must repeat that center profile)."""
    px = rgba.astype(int)
    h, w, _ = px.shape
    col_diff = np.abs(px - px[:, w // 2: w // 2 + 1]).mean(axis=(0, 2))
    row_diff = np.abs(px - px[h // 2: h // 2 + 1, :]).mean(axis=(1, 2))
    THR = 12.0
    left_hits = np.where(col_diff[: w // 2] > THR)[0]
    right_hits = np.where(col_diff[w // 2:] > THR)[0]
    top_hits = np.where(row_diff[: h // 2] > THR)[0]
    bottom_hits = np.where(row_diff[h // 2:] > THR)[0]
    left = int(left_hits.max()) + 1 if len(left_hits) else 0
    right = w - (w // 2 + int(right_hits.min())) if len(right_hits) else 0
    top = int(top_hits.max()) + 1 if len(top_hits) else 0
    bottom = h - (h // 2 + int(bottom_hits.min())) if len(bottom_hits) else 0
    return left, top, right, bottom


def main() -> None:
    os.makedirs(DST, exist_ok=True)
    for tpl, (stem, tol) in PICKS.items():
        rgb = np.asarray(Image.open(f"{SRC}/{stem}_00001_.png").convert("RGB")).astype(np.uint8)
        h, w, _ = rgb.shape
        bg = np.median(np.stack([rgb[3, 3], rgb[3, w - 4], rgb[h - 4, 3], rgb[h - 4, w - 4]]).astype(int), axis=0)
        keyed = flood(np.abs(rgb.astype(int) - bg).sum(axis=2) < tol, border_seed((h, w)))
        print(f"{tpl} <- {stem} ({w}x{h})")
        regions: dict[str, tuple] = {}
        if tpl == "card_frame":
            win = flood(np.abs(rgb.astype(int) - 255).sum(axis=2) < 90, point_seed((h, w), 380, 384))
            keyed |= win
            ys, xs = np.where(win)
            regions["content window"] = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
            panel = flood(np.abs(rgb.astype(int) - rgb[760, 384].astype(int)).sum(axis=2) < 70,
                          point_seed((h, w), 760, 384))
            ys, xs = np.where(panel)
            regions["text panel"] = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
            rgb = clean_parchment(rgb, regions["text panel"])
        if tpl == "icon_plate":
            disc = flood(np.abs(rgb.astype(int) - rgb[512, 512].astype(int)).sum(axis=2) < 120,
                         point_seed((h, w), 512, 512))
            ys, xs = np.where(disc)
            regions["glyph disc"] = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        alpha = np.where(keyed, 0, 255).astype(np.uint8)
        out = np.dstack([rgb, alpha])
        ys, xs = np.where(alpha > 0)
        crop = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
        img = Image.fromarray(out, "RGBA").crop(crop)
        img.save(f"{DST}/ui_{tpl}.png")
        print(f"  crop from raw: {crop} -> {img.size[0]}x{img.size[1]}  saved {DST}/ui_{tpl}.png")
        cx, cy = crop[0], crop[1]
        for name, (x0, y0, x1, y1) in regions.items():
            print(f"  {name} rect (in cropped px): ({x0 - cx}, {y0 - cy}, {x1 - cx}, {y1 - cy})")
        if tpl in ("panel", "button", "divider"):  # divider: only L/R matter (3-slice)
            l, t, r, b = nine_slice_margins(np.asarray(img))
            print(f"  9-slice margins (cropped px, L/T/R/B): {l}/{t}/{r}/{b}")


if __name__ == "__main__":
    main()
