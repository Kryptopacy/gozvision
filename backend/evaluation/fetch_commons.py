"""Fetch candidate evaluation images from Wikimedia Commons (freely licensed).

Searches the Commons file namespace for walking-hazard scenes, downloads the
top results at a fixed width, and records the Commons page URL so every image
can be traced back to its license and author.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dataset", "raw")
API = "https://commons.wikimedia.org/w/api.php"
UA = "GozVision-Evaluation/1.0 (research dataset fetch)"

QUERIES = [
    "sidewalk curb ramp",
    "stairs descending steps",
    "pavement crossing street",
    "concrete steps down",
    "pedestrian path curb",
    "subway stairs platform",
    "painted road line asphalt",
    "shadow on pavement",
]


def api(params):
    params = dict(params)
    params["format"] = "json"
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=45) as fh:
                return json.loads(fh.read().decode("utf-8"))
        except Exception as exc:
            print(f"    retry {attempt + 1} after {exc}")
            time.sleep(3 * (attempt + 1))
    return None


def search(query, limit=6):
    data = api({
        "action": "query",
        "list": "search",
        "srsearch": f"filetype:bitmap {query}",
        "srnamespace": "6",
        "srlimit": str(limit),
    })
    if not data:
        return []
    return [r["title"] for r in data.get("query", {}).get("search", [])]


def image_info(titles):
    data = api({
        "action": "query",
        "titles": "|".join(titles),
        "prop": "imageinfo",
        "iiprop": "url|extmetadata|size",
        "iiurlwidth": "1024",
    })
    if not data:
        return {}
    out = {}
    for page in data.get("query", {}).get("pages", {}).values():
        info = (page.get("imageinfo") or [{}])[0]
        if not info.get("thumburl"):
            continue
        meta = info.get("extmetadata", {})
        out[page["title"]] = {
            "thumburl": info["thumburl"],
            "page_url": info.get("descriptionurl"),
            "width": info.get("thumbwidth"),
            "height": info.get("thumbheight"),
            "license": (meta.get("LicenseShortName", {}) or {}).get("value", "unknown"),
            "artist": (meta.get("Artist", {}) or {}).get("value", "unknown"),
        }
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = {}
    for qi, query in enumerate(QUERIES):
        print(f"[{qi + 1}/{len(QUERIES)}] query: {query}")
        titles = search(query)
        if not titles:
            print("    no results")
            continue
        info = image_info(titles)
        for title, meta in info.items():
            name = f"commons_q{qi}_{abs(hash(title)) % 100000}.jpg"
            path = os.path.join(OUT, name)
            if os.path.exists(path) and os.path.getsize(path) > 5000:
                manifest[name] = dict(meta, title=title, query=query)
                continue
            try:
                req = urllib.request.Request(meta["thumburl"], headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=60) as fh:
                    data = fh.read()
                if len(data) < 5000:
                    continue
                with open(path, "wb") as out:
                    out.write(data)
                manifest[name] = dict(meta, title=title, query=query)
                print(f"    saved {name} ({len(data):,} B) <- {title[:60]}")
            except Exception as exc:
                print(f"    failed {title[:40]}: {exc}")
        time.sleep(1)

    mpath = os.path.join(OUT, "commons_manifest.json")
    with open(mpath, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
    print(f"\nwrote {mpath} with {len(manifest)} entries")


if __name__ == "__main__":
    sys.exit(main())
