# UI fonts — Noto Sans TC (locked family, style bible §10)

- `NotoSansTC-Regular.subset.otf` / `NotoSansTC-Bold.subset.otf` — subset builds of Noto Sans TC
  (source: `github.com/notofonts/noto-cjk`, `Sans/SubsetOTF/TC/`, fetched 2026-07-13).
- `LICENSE` — SIL Open Font License 1.1, copied verbatim from the official repo
  (`Sans/LICENSE`), verified at download time 2026-07-13.
- `charset.txt` — the subset's character inventory: every character appearing in `design/*.md`,
  `core/**`, `view/*.gd`, `tools/*.gd`, `poc-docs/*.md`, plus full printable ASCII and common
  zh-TW punctuation (regenerate + re-subset when UI strings gain new characters; missing glyphs
  render as tofu in the Part B captures).

Rebuild: `pyftsubset NotoSansTC-<w>.otf --text-file=charset.txt
--output-file=NotoSansTC-<w>.subset.otf --layout-features='*' --name-IDs='*'`
(fonttools via `uv tool install fonttools`; fetch fresh full binaries from the repo above).
