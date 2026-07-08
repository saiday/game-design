# pixelize.py — deterministic post-process; see doc/image-assets-generation-orchestrator-cookbook.md §5
from PIL import Image

def pixelize(src: str, dst: str, grid: tuple[int, int], palette_png: str, alpha_threshold: int = 128) -> None:
    img = Image.open(src).convert("RGBA")                       # generate at grid*N (match aspect!)
    small = img.resize(grid, Image.NEAREST)                     # snap to pixel grid, e.g. (64,64) or (96,128)
    alpha = small.getchannel("A").point(lambda a: 255 if a >= alpha_threshold else 0)
    pal = Image.open(palette_png).convert("RGB").quantize()     # master palette (§7 Phase 1)
    quant = small.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
    quant.putalpha(alpha)
    quant.save(dst)                                             # ship size
    quant.resize((grid[0] * 8, grid[1] * 8), Image.NEAREST).save(dst.replace(".png", "@8x.png"))  # review size
