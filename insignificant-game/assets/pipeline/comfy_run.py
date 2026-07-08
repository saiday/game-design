# comfy_run.py — submit an API-format workflow to ComfyUI and wait for the result.
# Usage: python3 comfy_run.py workflows/sdxl_txt2img.json [--seed N] [--prompt TEXT] [--prefix NAME]
# Prints the elapsed sampling time and the output image paths. See cookbook §4 for the driving rules.
import argparse
import json
import time
import urllib.request
import uuid

API = "http://127.0.0.1:8188"


def find_node(wf: dict, class_type: str) -> str:
    ids = [k for k, v in wf.items() if v["class_type"] == class_type]
    if len(ids) != 1:
        raise SystemExit(f"expected exactly one {class_type} node, found {len(ids)}")
    return ids[0]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("workflow")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--prompt")
    ap.add_argument("--prefix")
    args = ap.parse_args()

    with open(args.workflow) as f:
        wf = json.load(f)
    if args.seed is not None:
        wf[find_node(wf, "KSampler")]["inputs"]["seed"] = args.seed
    if args.prompt is not None:
        pos = wf[find_node(wf, "KSampler")]["inputs"]["positive"][0]
        wf[pos]["inputs"]["text"] = args.prompt
    if args.prefix is not None:
        wf[find_node(wf, "SaveImage")]["inputs"]["filename_prefix"] = args.prefix

    body = json.dumps({"prompt": wf, "client_id": str(uuid.uuid4())}).encode()
    req = urllib.request.Request(f"{API}/prompt", data=body, headers={"Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(req) as r:
        prompt_id = json.load(r)["prompt_id"]
    print(f"submitted prompt_id={prompt_id}")

    while True:
        time.sleep(1.0)
        with urllib.request.urlopen(f"{API}/history/{prompt_id}") as r:
            hist = json.load(r).get(prompt_id)
        if not hist:
            continue
        status = hist.get("status", {})
        if status.get("status_str") == "error":
            raise SystemExit(f"job failed: {json.dumps(status, indent=2)[:2000]}")
        if hist.get("outputs"):
            break
    elapsed = time.time() - t0
    print(f"done in {elapsed:.1f}s (submit-to-output, includes model load if first run)")
    for node_out in hist["outputs"].values():
        for img in node_out.get("images", []):
            print(f"output: {img['subfolder']}/{img['filename']}" if img["subfolder"] else f"output: {img['filename']}")


if __name__ == "__main__":
    main()
