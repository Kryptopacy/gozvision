"""Fetch real curb / stairs / sidewalk imagery for the labelled evaluation set.

Wikimedia Commons rejects unknown thumbnail widths with HTTP 400 and unknown
filenames with HTTP 404, so this script first queries the Commons API for the
actual file names of relevant images, then downloads a fixed-width thumbnail
for each via the `Special:FilePath` redirect.

Run with:  python evaluation/fetch_real_images.py
"""
import json
import os
import urllib.parse
import urllib.request

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dataset", "raw")
os.makedirs(OUT, exist_ok=True)

UA = "GozVision-Eval/1.0 (OpenCV AI Competition 2026 research build)"
API = "https://commons.wikimedia.org/w/api.php"

# Search terms for the physical hazards the system must detect.
QUERIES = {
    "curb_street": "curb street sidewalk edge",
    "sidewalk_curb": "sidewalk curb kerb",
    "stairs_down": "stairs descending steps",
    "pedestrian_crossing": "pedestrian crossing road",
    "ramp_sidewalk": "curb ramp wheelchair",
    "shadow_ground": "shadow on pavement ground",
}

WIDTH = 640


def _get(url: str, timeout: int = 40) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def search_files(term: str, limit: int = 4) -> list:
    """Query the Commons API for image file names matching a search term."""
    params = {
        "action": "query",
        "format": "json",
        "generator": "search",
        "gsrsearch": f"filetype:bitmap {term}",
        "gsrnamespace": "6",
        "gsrlimit": str(limit),
        "prop": "imageinfo",
        "iiprop": "url|size",
    }
    url = f"{API}?{urllib.parse.urlencode(params)}"
    try:
        data = json.loads(_get(url).decode("utf-8"))
    except Exception as exc:  # noqa: BLE001
        print("  search failed:", exc)
        return []

    pages = (data.get("query") or {}).get("pages") or {}
    out = []
    for page in pages.values():
        title = page.get("title", "")
        if not title.lower().endswith((".jpg", ".jpeg", ".png")):
            continue
        info = (page.get("imageinfo") or [{}])[0]
        if info.get("width", 0) < 500:
            continue
        out.append(title)
    return out


def thumb_url(filename: str, width: int = WIDTH) -> str:
    """Build a valid Wikimedia thumbnail URL via the Special:FilePath redirect."""
    name = urllib.parse.quote(filename.replace(" ", "_"))
    return f"https://commons.wikimedia.org/wiki/Special:FilePath/{name}?width={width}"


def main() -> int:
    failures = 0
    for slug, term in QUERIES.items():
        dest = os.path.join(OUT, f"{slug}.jpg")
        if os.path.exists(dest) and os.path.getsize(dest) > 1024:
            print("SKIP (exists)", slug)
            continue

        candidates = search_files(term)
        if not candidates:
            print("FAIL (no candidates)", slug)
            failures += 1
            continue

        saved = False
        for i, title in enumerate(candidates):
            try:
                data = _get(thumb_url(title))
                if len(data) < 1024:
                    continue
                with open(dest, "wb") as fh:
                    fh.write(data)
                print(f"OK {slug} <- {title} ({len(data)} bytes)")
                saved = True
                break
            except Exception as exc:  # noqa: BLE001
                print(f"  candidate {i} failed: {exc}")
        if not saved:
            print("FAIL", slug)
            failures += 1
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())

