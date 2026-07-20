# build_pickgate_review.py — generates a self-contained offline HTML review page for the units
# pick-gate round 2, one row per rendered cell (manifest's unit-candidate rows): thumbnail
# (base64-embedded JPEG, so the page is portable), the exact prompt used to render it (render-time
# truth from the manifest, not the batch script's current wording), an approve/reject choice, and a
# reject-reason / replacement-prompt field. Closed-short cells are pre-flagged reject with their
# reason pre-filled. Review state (choices + typed text) persists in the browser's localStorage
# across reloads. Run with the ComfyUI venv python from assets/pipeline/: writes
# review/pickgate_round2_units.html.
import base64
import io
import json
import os

from PIL import Image

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-units")
MANIFEST = "manifest.jsonl"
OUT_DIR = "review"
OUT = f"{OUT_DIR}/pickgate_round2_units.html"
THUMB = (560, 560)
JPEG_QUALITY = 82


def thumbnail_data_uri(stem: str) -> str:
    path = f"{SRC}/{stem}_00001_.png"
    im = Image.open(path).convert("RGB")
    im.thumbnail(THUMB, Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, format="JPEG", quality=JPEG_QUALITY)
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return f"data:image/jpeg;base64,{b64}", path


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    rows = [json.loads(l) for l in open(MANIFEST) if l.strip()]
    unit_rows = [r for r in rows if r.get("class") == "unit-candidate"]

    # subject is "{line}_era{era}" — split back out; group by line -> chain -> era
    grouped: dict[str, dict[int, dict[int, dict]]] = {}
    for r in unit_rows:
        line, era_str = r["subject"].rsplit("_era", 1)
        era = int(era_str)
        chain = r["chain"]
        grouped.setdefault(line, {}).setdefault(chain, {})[era] = r

    total = len(unit_rows)
    rejected_count = sum(1 for r in unit_rows if r["status"] == "rejected")
    candidate_count = total - rejected_count

    cells_html = []
    cell_index = 0
    for line in sorted(grouped):
        chains = grouped[line]
        cells_html.append(f'<section class="line-section"><h2>{line}</h2>')
        for chain in sorted(chains):
            eras = chains[chain]
            cells_html.append(f'<div class="chain-row"><h3>chain {chain}</h3><div class="cell-strip">')
            for era in sorted(eras):
                r = eras[era]
                cell_index += 1
                cell_id = r["id"]
                data_uri, full_path = thumbnail_data_uri(r["id"])
                is_rejected = r["status"] == "rejected"
                reason = (r.get("reject_reason") or "").replace('"', "&quot;")
                prompt = (r.get("prompt") or "").replace("<", "&lt;").replace(">", "&gt;")
                badge = (
                    f'<div class="badge badge-flagged">NEEDS DECISION</div>'
                    if is_rejected else ""
                )
                reason_html = (
                    f'<div class="reason">{reason}</div>' if is_rejected else ""
                )
                default_choice = "reject" if is_rejected else "approve"
                cells_html.append(f'''
<div class="cell" data-cell-id="{cell_id}" data-default-choice="{default_choice}" data-default-reason="{reason}">
  <div class="thumb-wrap">
    <img src="{data_uri}" alt="{cell_id}" loading="lazy">
    {badge}
  </div>
  <div class="meta">
    <div class="stem">{cell_id} <span class="era-tag">era {era}</span></div>
    {reason_html}
    <details class="prompt-box"><summary>prompt used</summary><textarea readonly rows="4">{prompt}</textarea></details>
    <div class="choice-row">
      <label><input type="radio" name="choice-{cell_id}" value="approve" class="choice-radio"> Approve</label>
      <label><input type="radio" name="choice-{cell_id}" value="reject" class="choice-radio"> Reject</label>
    </div>
    <textarea class="replacement-prompt" placeholder="New prompt to try instead (leave blank to just flag for discussion)..." rows="3" style="display:none"></textarea>
    <a class="fullres-link" href="file://{full_path}" target="_blank">view full-res PNG</a>
  </div>
</div>''')
            cells_html.append('</div></div>')
        cells_html.append('</section>')

    html = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Units Pick-Gate Round 2 — Review</title>
<style>
  :root {{
    --bg: #14161a; --panel: #1c1f26; --border: #2c313c; --text: #e6e8ec; --muted: #8b93a3;
    --accent: #5b9dff; --ok: #3ecf8e; --bad: #ff6b6b; --flag: #ffb020;
  }}
  @media (prefers-color-scheme: light) {{
    :root {{
      --bg: #f4f5f7; --panel: #ffffff; --border: #d8dce3; --text: #1a1d23; --muted: #5a6270;
      --accent: #2f6fed; --ok: #1f9d63; --bad: #d64545; --flag: #b8720a;
    }}
  }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          background: var(--bg); color: var(--text); }}
  header {{ position: sticky; top: 0; z-index: 10; background: var(--panel); border-bottom: 1px solid var(--border);
            padding: 14px 20px; display: flex; align-items: center; gap: 16px; flex-wrap: wrap; }}
  header h1 {{ font-size: 17px; margin: 0; margin-right: auto; }}
  .stat {{ font-size: 13px; color: var(--muted); }}
  .stat b {{ color: var(--text); }}
  button {{ background: var(--accent); color: white; border: none; padding: 8px 14px; border-radius: 6px;
            font-size: 13px; cursor: pointer; }}
  button.secondary {{ background: transparent; color: var(--accent); border: 1px solid var(--accent); }}
  main {{ padding: 20px; max-width: 1400px; margin: 0 auto; }}
  .line-section {{ margin-bottom: 32px; }}
  .line-section h2 {{ font-size: 20px; border-bottom: 2px solid var(--border); padding-bottom: 6px; }}
  .chain-row h3 {{ font-size: 14px; color: var(--muted); margin: 14px 0 8px; }}
  .cell-strip {{ display: flex; flex-wrap: wrap; gap: 14px; }}
  .cell {{ background: var(--panel); border: 1px solid var(--border); border-radius: 8px; width: 300px;
           overflow: hidden; display: flex; flex-direction: column; }}
  .cell.state-approve {{ border-color: var(--ok); }}
  .cell.state-reject {{ border-color: var(--bad); }}
  .thumb-wrap {{ position: relative; background: #000; }}
  .thumb-wrap img {{ width: 100%; display: block; }}
  .badge {{ position: absolute; top: 6px; left: 6px; font-size: 10px; font-weight: 700; padding: 3px 7px;
            border-radius: 4px; letter-spacing: 0.03em; }}
  .badge-flagged {{ background: var(--flag); color: #1a1200; }}
  .meta {{ padding: 10px 12px; display: flex; flex-direction: column; gap: 8px; }}
  .stem {{ font-size: 11px; color: var(--muted); word-break: break-all; }}
  .era-tag {{ background: var(--border); padding: 1px 6px; border-radius: 4px; margin-left: 4px; }}
  .reason {{ font-size: 12px; color: var(--flag); background: color-mix(in srgb, var(--flag) 15%, transparent);
             border-radius: 5px; padding: 6px 8px; }}
  .prompt-box summary {{ cursor: pointer; font-size: 12px; color: var(--accent); }}
  .prompt-box textarea {{ width: 100%; margin-top: 6px; font-size: 11px; background: var(--bg);
                           color: var(--text); border: 1px solid var(--border); border-radius: 4px;
                           resize: vertical; font-family: ui-monospace, monospace; }}
  .choice-row {{ display: flex; gap: 14px; font-size: 13px; }}
  .replacement-prompt {{ width: 100%; font-size: 12px; background: var(--bg); color: var(--text);
                          border: 1px solid var(--border); border-radius: 4px; resize: vertical; }}
  .fullres-link {{ font-size: 11px; color: var(--accent); text-decoration: none; }}
  .fullres-link:hover {{ text-decoration: underline; }}
  #toast {{ position: fixed; bottom: 20px; right: 20px; background: var(--ok); color: #06210f;
            padding: 10px 16px; border-radius: 6px; font-size: 13px; display: none; }}
</style>
</head>
<body>
<header>
  <h1>Units Pick-Gate Round 2</h1>
  <span class="stat"><b id="approve-count">0</b> approved</span>
  <span class="stat"><b id="reject-count">0</b> rejected</span>
  <span class="stat"><b id="pending-count">0</b> pending / {total} total</span>
  <button class="secondary" id="filter-flagged">Show only flagged ({rejected_count})</button>
  <button class="secondary" id="filter-all">Show all</button>
  <button id="export-btn">Export review JSON</button>
</header>
<main>
<p style="color:var(--muted); font-size:13px; max-width:900px;">
  One card per rendered image. <b style="color:var(--flag)">NEEDS DECISION</b> cards are lines/cells
  that failed 3-4 independent wording-fix attempts each and were deliberately closed short rather
  than iterated further — the note under the image explains what was tried. Everything else already
  converged clean. Pick Approve/Reject per card; a Reject reveals a text box for a replacement prompt
  (leave it blank to just flag the card for discussion). Your choices are saved in this browser
  automatically. When done, click "Export review JSON" and send the downloaded file back.
</p>
{''.join(cells_html)}
</main>
<div id="toast"></div>
<script>
const STORAGE_KEY = "pickgate_round2_units_review";
function loadState() {{
  try {{ return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {{}}; }} catch (e) {{ return {{}}; }}
}}
function saveState(state) {{ localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); }}

const state = loadState();
const cells = document.querySelectorAll(".cell");

function applyCellState(cell) {{
  const id = cell.dataset.cellId;
  const saved = state[id];
  const choice = saved ? saved.choice : cell.dataset.defaultChoice;
  const replacement = saved ? saved.replacement : "";
  const radio = cell.querySelector(`input[value="${{choice}}"]`);
  if (radio) radio.checked = true;
  const box = cell.querySelector(".replacement-prompt");
  box.style.display = choice === "reject" ? "block" : "none";
  if (replacement) box.value = replacement;
  else if (choice === "reject" && cell.dataset.defaultReason) box.placeholder = cell.dataset.defaultReason;
  cell.classList.remove("state-approve", "state-reject");
  cell.classList.add(choice === "reject" ? "state-reject" : "state-approve");
}}

function updateCounts() {{
  let a = 0, r = 0;
  cells.forEach(c => {{
    const checked = c.querySelector("input:checked");
    if (checked && checked.value === "approve") a++;
    else if (checked && checked.value === "reject") r++;
  }});
  document.getElementById("approve-count").textContent = a;
  document.getElementById("reject-count").textContent = r;
  document.getElementById("pending-count").textContent = cells.length - a - r;
}}

cells.forEach(cell => {{
  const id = cell.dataset.cellId;
  applyCellState(cell);
  cell.querySelectorAll(".choice-radio").forEach(radio => {{
    radio.addEventListener("change", () => {{
      const box = cell.querySelector(".replacement-prompt");
      box.style.display = radio.value === "reject" ? "block" : "none";
      cell.classList.remove("state-approve", "state-reject");
      cell.classList.add(radio.value === "reject" ? "state-reject" : "state-approve");
      state[id] = {{ choice: radio.value, replacement: box.value }};
      saveState(state);
      updateCounts();
    }});
  }});
  cell.querySelector(".replacement-prompt").addEventListener("input", (e) => {{
    const checked = cell.querySelector("input:checked");
    state[id] = {{ choice: checked ? checked.value : cell.dataset.defaultChoice, replacement: e.target.value }};
    saveState(state);
  }});
}});
updateCounts();

document.getElementById("filter-flagged").addEventListener("click", () => {{
  document.querySelectorAll(".cell").forEach(c => {{
    c.style.display = c.querySelector(".badge-flagged") ? "flex" : "none";
  }});
  document.querySelectorAll(".chain-row, .line-section").forEach(sec => {{
    const visible = [...sec.querySelectorAll(".cell")].some(c => c.style.display !== "none");
    sec.style.display = visible ? "" : "none";
  }});
}});
document.getElementById("filter-all").addEventListener("click", () => {{
  document.querySelectorAll(".cell, .chain-row, .line-section").forEach(el => el.style.display = "");
}});

document.getElementById("export-btn").addEventListener("click", () => {{
  const out = {{}};
  cells.forEach(cell => {{
    const id = cell.dataset.cellId;
    const checked = cell.querySelector("input:checked");
    const box = cell.querySelector(".replacement-prompt");
    out[id] = {{
      choice: checked ? checked.value : cell.dataset.defaultChoice,
      replacement_prompt: box.value || null,
      was_flagged: cell.querySelector(".badge-flagged") !== null,
    }};
  }});
  const blob = new Blob([JSON.stringify(out, null, 2)], {{ type: "application/json" }});
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "pickgate_round2_units_review.json";
  a.click();
  const toast = document.getElementById("toast");
  toast.textContent = "Exported — send the downloaded file back";
  toast.style.display = "block";
  setTimeout(() => toast.style.display = "none", 3000);
}});
</script>
</body>
</html>"""

    with open(OUT, "w") as f:
        f.write(html)
    size_mb = os.path.getsize(OUT) / 1024 / 1024
    print(f"wrote {OUT} ({size_mb:.1f} MB), {total} cells ({candidate_count} candidate, {rejected_count} flagged)")


if __name__ == "__main__":
    main()
