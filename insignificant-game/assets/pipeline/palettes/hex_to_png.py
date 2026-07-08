# hex_to_png.py — build an Nx1 palette PNG from a Lospec .hex file (one RRGGBB per line).
# The PNG is what pixelize.py quantizes against (cookbook §5/§7).
# Usage: python hex_to_png.py endesga-32.hex  -> endesga-32.png
import sys

from PIL import Image


def main() -> None:
    src = sys.argv[1]
    colors = [line.strip().lstrip("#") for line in open(src) if line.strip()]
    img = Image.new("RGB", (len(colors), 1))
    for x, c in enumerate(colors):
        img.putpixel((x, 0), tuple(int(c[i : i + 2], 16) for i in (0, 2, 4)))
    dst = src.rsplit(".", 1)[0] + ".png"
    img.save(dst)
    print(f"{dst}: {len(colors)} colors")


if __name__ == "__main__":
    main()
