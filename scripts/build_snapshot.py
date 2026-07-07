#!/usr/bin/env python3
"""Builds the bundled data snapshot for TFT Overlay.

Downloads (or reuses) raw data from CommunityDragon + MetaTFT and distills the
four JSON files the app ships with:
  augments.json  — curated S–D tiers + names/descs/icons
  items.json     — completed-item stats (avg place from placement histograms)
  comps.json     — top comp clusters with avg place / play count
  odds.json      — shop odds per level per cost

Usage: python3 scripts/build_snapshot.py [raw_dir] [out_dir]
Raw files expected (downloaded if missing): cdragon.json, augtiers.json,
items.json, clusterinfo.json, tables.json
"""
import hashlib
import json
import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

RAW_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("scripts/raw")
OUT_DIR = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("TFTOverlay/Resources")

SOURCES = {
    "cdragon.json": "https://raw.communitydragon.org/latest/cdragon/tft/en_us.json",
    "augtiers.json": "https://api-hc.metatft.com/tft-stat-api/augments_tiers",
    "items.json": "https://api-hc.metatft.com/tft-stat-api/items",
    "clusterinfo.json": "https://api-hc.metatft.com/tft-comps-api/latest_cluster_info",
    "compaug.json": "https://api-hc.metatft.com/tft-comps-api/comp_augment_tiers",
    "tables.json": "https://data.metatft.com/lookups/latest_TFTSet17_tables.json",
}


def fetch_all():
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for name, url in SOURCES.items():
        path = RAW_DIR / name
        if path.exists():
            continue
        print(f"downloading {name} …")
        req = urllib.request.Request(url, headers={"User-Agent": "tft-overlay-snapshot/1.0"})
        path.write_bytes(urllib.request.urlopen(req, timeout=60).read())


def load(name):
    return json.loads((RAW_DIR / name).read_text())


def clean_desc(desc):
    if not desc:
        return ""
    desc = re.sub(r"@[^@]*@", "?", desc)         # scripting placeholders
    desc = desc.replace("<br>", "\n").replace("<br/>", "\n")
    desc = re.sub(r"<[^>]+>", "", desc)           # remaining markup
    return re.sub(r"[ \t]+", " ", desc).strip()


def icon_url(path):
    if not path:
        return None
    p = path.lower()
    for ext in (".dds", ".tex"):
        if p.endswith(ext):
            p = p[: -len(ext)] + ".png"
    return f"https://raw.communitydragon.org/latest/game/{p}"


# Icons get bundled into the app so the UI never waits on the network.
_icon_jobs = {}


def local_icon(path):
    url = icon_url(path)
    if not url:
        return None
    name = hashlib.sha1(url.encode()).hexdigest()[:16] + ".png"
    _icon_jobs[name] = url
    return name


def download_icons():
    icons_dir = OUT_DIR / "Icons"
    icons_dir.mkdir(parents=True, exist_ok=True)

    def fetch(job):
        name, url = job
        target = icons_dir / name
        if target.exists():
            return 0
        req = urllib.request.Request(url, headers={"User-Agent": "tft-overlay-snapshot/1.0"})
        for attempt in range(3):
            try:
                target.write_bytes(urllib.request.urlopen(req, timeout=30).read())
                return 1
            except Exception as e:
                if attempt == 2:
                    print(f"icon failed: {url} ({e!r})")
                    return 0

    with ThreadPoolExecutor(16) as pool:
        fetched = sum(pool.map(fetch, _icon_jobs.items()))
    total_kb = sum(f.stat().st_size for f in icons_dir.glob("*.png")) // 1024
    print(f"icons: {len(_icon_jobs)} referenced, {fetched} downloaded, {total_kb} KB total")


def main():
    fetch_all()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cdragon = load("cdragon.json")
    by_api_name = {i["apiName"]: i for i in cdragon["items"] if i.get("apiName")}
    # Champions live under setData, not items; later sets win on apiName clashes.
    champs = {}
    traits_lookup = {}
    for set_data in sorted(cdragon.get("setData", []), key=lambda s: s.get("number") or 0):
        for champ in set_data.get("champions", []):
            if champ.get("apiName"):
                champs[champ["apiName"]] = champ
        for trait in set_data.get("traits", []):
            if trait.get("apiName"):
                traits_lookup[trait["apiName"]] = trait

    # --- augments: curated tiers joined with static data ---
    def augment_rarity(icon):
        """Rarity is encoded in the icon filename: _I/-I = Silver,
        _II = Gold, _III = Prismatic; some sets use trailing digits 1/2/3."""
        if not icon:
            return "unknown"
        base = icon.split("/")[-1].split(".")[0]  # e.g. "HeadStart_I", "CalculatedLoss2"
        m = re.search(r"[-_](I{1,3})$", base, re.IGNORECASE)
        if m:
            return {1: "silver", 2: "gold", 3: "prismatic"}[len(m.group(1))]
        m = re.search(r"([123])$", base)
        if m:
            return {"1": "silver", "2": "gold", "3": "prismatic"}[m.group(1)]
        return "unknown"

    tiers = load("augtiers.json")["content"]["content"]["tierList"]
    augments = []
    for group in tiers:
        for entry in group.get("content", []):
            info = by_api_name.get(entry["id"], {})
            augments.append({
                "id": entry["id"],
                "tier": group.get("label", "?"),
                "name": info.get("name") or entry["id"],
                "desc": clean_desc(info.get("desc")),
                "icon": local_icon(info.get("icon")),
                "rarity": augment_rarity(info.get("icon")),
            })
    (OUT_DIR / "augments.json").write_text(json.dumps(augments, indent=1))
    print(f"augments.json: {len(augments)} augments in {len(tiers)} tiers")

    # --- items: avg placement from histograms, categorized ---
    def item_category(api_name, composition, tags):
        lowered = api_name.lower()
        if "emblem" in lowered:
            return "emblem"
        if "radiant" in lowered or api_name.startswith("TFT5_Item"):
            return "radiant"
        if "artifact" in lowered or "ornn" in lowered:
            return "artifact"
        if "component" in tags:
            return "component"
        if len(composition) == 2:
            return "completed"
        return "other"

    items_out = []
    for row in load("items.json")["results"]:
        places = row.get("places") or []
        games = sum(places)
        if games == 0:
            continue
        info = by_api_name.get(row["itemName"], {})
        name = info.get("name")
        if not name:
            continue
        composition = info.get("composition") or []
        avg = sum((i + 1) * n for i, n in enumerate(places)) / games
        top4 = sum(places[:4]) / games
        items_out.append({
            "id": row["itemName"],
            "name": name,
            "desc": clean_desc(info.get("desc")),
            "icon": local_icon(info.get("icon")),
            "category": item_category(row["itemName"], composition, info.get("tags") or []),
            "avgPlace": round(avg, 2),
            "top4": round(top4, 4),
            "games": games,
        })
    items_out.sort(key=lambda x: x["avgPlace"])
    (OUT_DIR / "items.json").write_text(json.dumps(items_out, indent=1))
    print(f"items.json: {len(items_out)} items")

    # --- comps: clusters + per-comp stats from comp_details ---
    info = load("clusterinfo.json")["cluster_info"]
    cluster_id = info["cluster_id"]
    clusters = info["cluster_details"]["clusters"]
    details_dir = RAW_DIR / "comp_details"
    details_dir.mkdir(exist_ok=True)

    def display_name(api_name):
        key = api_name.strip()
        bare = re.sub(r"_\d+$", "", key)  # cluster trait strings carry a level suffix
        entry = (by_api_name.get(key) or champs.get(key)
                 or traits_lookup.get(key) or traits_lookup.get(bare))
        if entry and entry.get("name"):
            return entry["name"]
        # "TFT17_SpaceGroove" -> "Space Groove"
        tail = bare.split("_")[-1]
        return re.sub(r"(?<=[a-z])(?=[A-Z])", " ", tail)

    comp_augments = load("compaug.json").get("results", {})

    comps = []
    for c in clusters:
        comp_id = c["Cluster"]
        cache = details_dir / f"{comp_id}.json"
        if not cache.exists():
            url = (f"https://api-hc.metatft.com/tft-comps-api/comp_details"
                   f"?cluster_id={cluster_id}&comp={comp_id}")
            req = urllib.request.Request(url, headers={"User-Agent": "tft-overlay-snapshot/1.0"})
            for attempt in range(3):
                try:
                    cache.write_bytes(urllib.request.urlopen(req, timeout=30).read())
                    break
                except Exception as e:
                    if attempt == 2:
                        raise
                    print(f"retry {comp_id} after {e!r}")
        details = json.loads(cache.read_text())["results"]
        stats = (details.get("placements") or [{}])[0]

        # Playstyle from roll timing: reroll comps spend their gold rolling at
        # levels 5–7 (early-roll share ~0.8+), standard/fast-9 comps roll at 8+.
        # Validated: Asol fast-9 = 0.06 early share, Pantheon reroll = 0.90.
        style, style_detail = "standard", None
        roll_dist = details.get("rerolls") or {}
        total_rolls = sum(max(v.get("rerolls", 0), 0) for v in roll_dist.values())
        early_rolls = sum(
            max(v.get("rerolls", 0), 0)
            for lvl, v in roll_dist.items() if int(lvl) <= 7
        )
        if total_rolls and early_rolls / total_rolls >= 0.6:
            style = "reroll"
            # Name the reroll target: the cheap, itemized unit most often 3-starred.
            best = None
            for unit_stat in details.get("unit_stats") or []:
                tier3 = next((t for t in unit_stat.get("tiers", []) if t.get("tier") == 3), None)
                if not tier3 or tier3.get("pcnt", 0) < 0.55:
                    continue
                champ = champs.get(unit_stat["unit"], {})
                if (champ.get("cost") or 9) > 3:
                    continue
                item_dist = unit_stat.get("num_items") or []
                avg_items = sum(n.get("num_items", 0) * n.get("pcnt", 0) for n in item_dist)
                weight = tier3["pcnt"] * tier3.get("count", 0) * (1 + avg_items)
                if best is None or weight > best[0]:
                    best = (weight, champ.get("name") or unit_stat["unit"].split("_")[-1])
            if best:
                style_detail = f"{best[1]} 3★"
        else:
            levels = details.get("final_levels") or []
            total = sum(x.get("count", 0) for x in levels)
            high = sum(x.get("count", 0) for x in levels if int(x.get("level", "0")) >= 9)
            if total and high / total >= 0.35:
                style = "fast9"

        title = " · ".join(dict.fromkeys(
            display_name(n["name"]) for n in (c.get("name") or [])[:2]
        )) or "Unnamed comp"
        # Per-unit: 3-star rate and the most-played (BiS) item build.
        star3_units = set()
        for unit_stat in details.get("unit_stats") or []:
            tier3 = next((t for t in unit_stat.get("tiers", []) if t.get("tier") == 3), None)
            if tier3 and tier3.get("pcnt", 0) >= 0.5:
                star3_units.add(unit_stat["unit"])
        best_builds = {}
        for build in details.get("builds") or []:
            unit_api = build.get("unit")
            names = build.get("buildName") or []
            if not unit_api or len(names) < 2:
                continue
            current = best_builds.get(unit_api)
            if current is None or build.get("count", 0) > current.get("count", 0):
                best_builds[unit_api] = build

        units = []
        seen_units = set()
        for api_name in (c.get("units_string") or c.get("units") or "").split(","):
            api_name = api_name.strip()
            if not api_name or api_name in seen_units:  # centroids repeat units
                continue
            seen_units.add(api_name)
            champ = champs.get(api_name, {})
            build_items = [
                local_icon(by_api_name.get(item_api, {}).get("icon"))
                for item_api in (best_builds.get(api_name, {}).get("buildName") or [])
                if by_api_name.get(item_api, {}).get("icon")
            ]
            units.append({
                "name": champ.get("name") or api_name.split("_")[-1],
                "icon": local_icon(champ.get("squareIcon") or champ.get("tileIcon")),
                "star3": api_name in star3_units,
                "items": build_items,
            })
        traits = [
            display_name(t) for t in (c.get("traits_string") or "").split(",") if t.strip()
        ]
        # Curated augment recommendations for this comp (S/A/B).
        recommended = []
        for rec in (comp_augments.get(str(comp_id), {}).get("augments") or [])[:12]:
            info = by_api_name.get(rec.get("id"), {})
            if not info.get("name"):
                continue
            recommended.append({
                "name": info["name"],
                "icon": local_icon(info.get("icon")),
                "tier": rec.get("tier", "?"),
            })

        comps.append({
            "id": comp_id,
            "title": title,
            "units": units,
            "traits": traits,
            "style": style,
            "styleDetail": style_detail,
            "augments": recommended,
            "avgPlace": round(stats.get("avg", 0), 2) or None,
            "games": stats.get("count"),
        })
    comps.sort(key=lambda x: x["avgPlace"] or 9)
    (OUT_DIR / "comps.json").write_text(json.dumps(comps, indent=1))
    print(f"comps.json: {len(comps)} comps with stats")

    # --- shop odds ---
    tables = load("tables.json")
    shop = tables["dropRates"]["Shop"]
    odds = [{"level": i + 1, "odds": row} for i, row in enumerate(shop)]
    (OUT_DIR / "odds.json").write_text(json.dumps(odds, indent=1))
    print(f"odds.json: {len(odds)} levels")

    # --- unit pools (bag sizes + distinct shop champs per cost) ---
    tft_set = load("clusterinfo.json")["cluster_info"]["tft_set"]
    set_number = int(re.sub(r"\D", "", tft_set))  # "TFTSet17" -> 17
    bag_sizes = [int(tables["bagSizes"].get(str(c), 0)) for c in range(1, 6)]
    seen_champs = set()
    champ_counts = [0] * 5
    champions = []
    for set_data in cdragon.get("setData", []):
        if set_data.get("number") != set_number:
            continue
        for champ in set_data.get("champions", []):
            api = champ.get("apiName") or ""
            cost = champ.get("cost")
            if api in seen_champs or not champ.get("traits") or cost not in (1, 2, 3, 4, 5):
                continue
            seen_champs.add(api)
            champ_counts[cost - 1] += 1
            champions.append({
                "name": champ.get("name") or api.split("_")[-1],
                "cost": cost,
                "icon": local_icon(champ.get("squareIcon") or champ.get("tileIcon")),
            })
    champions.sort(key=lambda c: (c["cost"], c["name"]))
    (OUT_DIR / "champions.json").write_text(json.dumps(champions, indent=1))
    (OUT_DIR / "pools.json").write_text(json.dumps(
        {"bagSizes": bag_sizes, "champCounts": champ_counts}, indent=1
    ))
    print(f"pools.json: bags {bag_sizes}, champs {champ_counts}; champions.json: {len(champions)}")

    download_icons()


if __name__ == "__main__":
    main()
