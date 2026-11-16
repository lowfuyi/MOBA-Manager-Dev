"""Validate game data against the JSON schemas and the rules JSON Schema cannot express.

Usage: python3 tools/validate_data.py [data_dir]   (default: game/data)
Checks, for every *.json that is not a schema:
  heroes:  power_early + power_mid + power_late == 144 + 3*difficulty; ids unique;
           strong_vs refers to existing hero ids (within the file); no self-counter
  players: potential >= stat for all 8 stats and <= 99; ids unique
  clubs + world: rosters exist, role guarantee, unique names, block list, hero/club name collisions
  tutorial: 27 steps with the TUTORIAL.md 3.2 ids in order, chapters 1 to 7 and their step ranges, tags from the
           TUTORIAL.md 8 list, events from the 7.5 list, every text key present in ../i18n/en.json, resume targets exist
Files named heroes*.json, players*.json, clubs*.json and tutorial*.json are picked by name.
"""
import json, pathlib, sys
from jsonschema import Draft202012Validator

ROOT = pathlib.Path(__file__).resolve().parent.parent
STATS = ["mec", "sen", "lan", "tft", "mac", "com", "con", "clu"]

def load(p): return json.loads(pathlib.Path(p).read_text())

def check_heroes(items, schema):
    errs, ids = [], set()
    v = Draft202012Validator(schema)
    for h in items:
        hid = h.get("id", "?")
        errs += [f"hero {hid}: {e.message}" for e in v.iter_errors(h)]
        if hid in ids: errs.append(f"hero {hid}: duplicate id")
        ids.add(hid)
        try:
            if h["power_early"] + h["power_mid"] + h["power_late"] != 144 + 3 * h["difficulty"]:
                errs.append(f"hero {hid}: power sum must be 144 + 3*difficulty")
        except KeyError:
            pass
    for h in items:
        for t in h.get("strong_vs", []):
            if t not in ids: errs.append(f"hero {h.get('id')}: strong_vs unknown id {t}")
            if t == h.get("id"): errs.append(f"hero {h.get('id')}: counters itself")
    return errs

def check_players(items, schema):
    errs, ids = [], set()
    v = Draft202012Validator(schema)
    for p in items:
        pid = p.get("id", "?")
        errs += [f"player {pid}: {e.message}" for e in v.iter_errors(p)]
        if pid in ids: errs.append(f"player {pid}: duplicate id")
        ids.add(pid)
        for s in STATS:
            try:
                if not (p["stats"][s] <= p["potential"][s] <= 99):
                    errs.append(f"player {pid}: potential must be >= stat and <= 99 ({s})")
            except KeyError:
                pass
    return errs

def check_clubs(items, schema):
    errs, ids = [], set()
    v = Draft202012Validator(schema)
    for c in items:
        cid = c.get("id", "?")
        errs += [f"club {cid}: {e.message}" for e in v.iter_errors(c)]
        if cid in ids: errs.append(f"club {cid}: duplicate id")
        ids.add(cid)
    return errs


def check_world(heroes, players, clubs, block):
    """Cross-file rules for the generated league (GDD section 12)."""
    errs = []
    pid = {p["id"]: p for p in players}
    seen = {}
    for c in clubs:
        roster = [pid.get(i) for i in c["player_ids"]]
        if None in roster:
            errs.append(f"club {c['id']}: unknown player id"); continue
        for p in roster:
            if p["club"] != c["id"]: errs.append(f"player {p['id']}: club field is {p['club']}, roster says {c['id']}")
            if p["id"] in seen: errs.append(f"player {p['id']}: on two rosters")
            seen[p["id"]] = c["id"]
        for slot in ("top", "jg", "mid", "bot", "sup"):
            prim = [p for p in roster if p["role_primary"] == slot]
            able = [p for p in roster if slot in (p["role_primary"], p.get("role_secondary"))]
            if len(prim) < 1 or len(able) < 2: errs.append(f"club {c['id']}: role guarantee broken for {slot}")
    for p in players:
        if p["club"] is not None and p["id"] not in seen: errs.append(f"player {p['id']}: has club {p['club']} but is on no roster")
    names = [p["name"].lower() for p in players]
    if len(set(names)) != len(names): errs.append("duplicate player names")
    forbidden = {h["name"].lower() for h in heroes} | {c["name"].lower() for c in clubs}
    for n in names:
        if n in forbidden: errs.append(f"player name {n} collides with a hero or club name")
        if any(n == b or (len(b) >= 5 and b in n) for b in block): errs.append(f"player name {n} is on the block list")
    return errs


# ---- tutorial (build plan 0.7 I-11; TUTORIAL.md 3.2, 7.5, 8) -------------------------------------------------------
TUTORIAL_IDS = ["welcome", "home_card", "tabs", "tab_squad", "squad_bench", "player_card",
                "tab_plan", "plan_practice", "quick_match", "matchups", "start_draft",
                "ban", "pick", "role", "coach_rest",
                "open_plan", "coach_suggest", "start_match", "watch", "see_report",
                "result", "why", "continue",
                "tab_club", "form_tile", "form_switch", "finish"]
TUTORIAL_CHAPTER_RANGES = {1: (1, 4), 2: (5, 6), 3: (7, 11), 4: (12, 15), 5: (16, 20), 6: (21, 23), 7: (24, 27)}
# TUTORIAL.md section 8: every coach id (first-run and lesson/help ids).
TUTORIAL_TAGS = {
    "tabbar", "tab.squad", "tab.plan", "tab.club", "tab.home", "tab.more", "help.button", "screen.back",
    "home.next_card", "home.play", "home.attention", "home.tile.standing", "home.tile.chem", "home.offer",
    "squad.bench.0", "roster.card.head", "squad.bench.expiring", "roster.card.contract", "roster.card.renew",
    "roster.card.release", "squad.token.top", "squad.picker.head",
    "plan.tile.practice", "plan.tile.training", "plan.tile.chem", "practice.quick",
    "training.preview", "training.row.0", "training.picker", "chem.summary", "chem.map", "chem.training",
    "prematch.matchups", "prematch.start_draft",
    "draft.choices", "draft.slot_list", "draft.sheet.confirm", "draft.auto_rest", "draft.game_plan", "draft.hero_grid",
    "gp.coach", "gp.coach_apply", "gp.start_match", "gp.edge", "gp.contests", "gp.tabs", "plan.chip", "gp.sliders",
    "match.controls", "match.report_btn",
    "report.result", "report.why", "report.why_sheet", "report.continue", "report.payoff", "report.tip",
    "club.tile.form", "club.tile.finance", "club.tile.fa", "stand.metric", "standings.table", "standings.tabs",
    "fin.balance", "fin.cap", "fin.sponsor", "fa.filters", "fa.row.0", "settings.help_card", "settings.replay"}
# TUTORIAL.md 7.5, plus the three card-button events the machine reads (Start, Next, Go to Home).
TUTORIAL_EVENTS = {"open:player_card", "open:lane_picker", "open:training_picker", "draft:sheet", "draft:ban",
                   "draft:pick", "draft:done", "gp:coach_open", "gp:coach_apply", "gp:coach_close",
                   "open:report_why", "stand:metric", "match:speed", "match:skip", "match:end"}
TUTORIAL_BUTTON_EVENTS = {"tut:start", "tut:next", "tut:finish"}
TUTORIAL_KINDS = {"modal": 2, "info": 5, "do": 20}      # TUTORIAL.md 3.2 "Counts"


def _event_ok(ev):
    if ev in TUTORIAL_EVENTS or ev in TUTORIAL_BUTTON_EVENTS: return True
    return ev.startswith("tap:") and ev[4:] in TUTORIAL_TAGS or ev.startswith("screen:")


def _step_keys(st):
    keys = [st[k] for k in ("key", "key_win", "key_loss") if k in st]
    keys += list(st.get("variants", {}).values())
    if "stage_b" in st: keys.append(st["stage_b"]["key"])
    if "shortcut" in st: keys.append(st["shortcut"]["key"])
    return keys


def check_tutorial(doc, schema, strings=None):
    """strings: the en.json table (dict) or None to skip the text key check."""
    errs = [f"tutorial: {e.message}" for e in Draft202012Validator(schema).iter_errors(doc)]
    if errs: return errs                                  # the rest assumes the shape is right
    steps = doc["steps"]
    ids = [s["id"] for s in steps]
    if len(set(ids)) != len(ids): errs.append("tutorial: duplicate step id")
    if ids != TUTORIAL_IDS: errs.append(f"tutorial: step ids are not the 27 of TUTORIAL.md 3.2 in order: {ids}")
    for i, st in enumerate(steps):
        n, sid = i + 1, st["id"]
        lo, hi = TUTORIAL_CHAPTER_RANGES.get(st["chapter"], (0, 0))
        if not lo <= n <= hi: errs.append(f"step {sid}: chapter {st['chapter']} does not hold step {n}")
        for t in st["target"] + st.get("stage_b", {}).get("target", []):
            if t not in TUTORIAL_TAGS: errs.append(f"step {sid}: tag id {t} is not in the TUTORIAL.md 8 list")
        if st["kind"] == "modal" and st["target"]: errs.append(f"step {sid}: a modal has no target")
        if st["kind"] != "modal" and not st["target"]: errs.append(f"step {sid}: needs a target")
        for ev in st["done_on"]:
            if not _event_ok(ev): errs.append(f"step {sid}: done_on {ev} is not in the TUTORIAL.md 7.5 list")
        for ev in st.get("done_data", {}):
            if ev not in st["done_on"]: errs.append(f"step {sid}: done_data for {ev} which is not in done_on")
        sb = st.get("stage_b")
        if sb and not _event_ok(sb["on"]): errs.append(f"step {sid}: stage_b.on {sb['on']} is not in the 7.5 list")
        own = set(st["target"]) | set(sb["target"] if sb else [])
        for ev in st["done_on"] + ([sb["on"]] if sb else []):
            if ev.startswith("tap:") and ev[4:] not in own:
                errs.append(f"step {sid}: waits for {ev} but does not highlight {ev[4:]}")
        cond = st.get("skip_if", "")
        if cond.startswith("event_seen:") and not _event_ok(cond[len("event_seen:"):]):
            errs.append(f"step {sid}: skip_if event {cond} is not in the 7.5 list")
        if ("skip" in st["buttons"]) != (st["skip"] != "none"):
            errs.append(f"step {sid}: the Skip button and the skip code {st['skip']} disagree")
        if ("shortcut" in st["buttons"]) != ("shortcut" in st):
            errs.append(f"step {sid}: shortcut button and shortcut definition disagree")
        if st.get("hold_armed") and not sb: errs.append(f"step {sid}: hold_armed needs a stage_b")
        if "key" not in st and not ("key_win" in st and "key_loss" in st):
            errs.append(f"step {sid}: no text key")
        if strings is not None:
            for k in _step_keys(st):
                if k not in strings: errs.append(f"step {sid}: text key {k} is not in en.json")
    ch = doc["chapters"]
    if [c["n"] for c in ch] != list(range(1, 8)): errs.append("tutorial: chapters must be 1 to 7 in order")
    for c in ch:
        if c["resume"] not in ids: errs.append(f"chapter {c['n']}: resume step {c['resume']} does not exist")
        if strings is not None and c["key"] not in strings: errs.append(f"chapter {c['n']}: text key {c['key']} is not in en.json")
    kinds = {"modal": 0, "info": 0, "do": 0}
    for st in steps: kinds["do" if st["kind"] in ("tap", "event") else st["kind"]] += 1
    if kinds != TUTORIAL_KINDS: errs.append(f"tutorial: step kinds {kinds}, TUTORIAL.md 3.2 says {TUTORIAL_KINDS}")
    return errs


def validate_dir(data_dir):
    data_dir = pathlib.Path(data_dir)
    hs, ps = load(data_dir / "schema/hero.schema.json"), load(data_dir / "schema/player.schema.json")
    cs = load(data_dir / "schema/club.schema.json")
    errs = []
    for f in sorted(data_dir.rglob("*.json")):
        if "schema" in f.parts or "names" in f.parts: continue
        if f.name.startswith("heroes"): errs += [f"{f.name}: {e}" for e in check_heroes(load(f), hs)]
        elif f.name.startswith("players"): errs += [f"{f.name}: {e}" for e in check_players(load(f), ps)]
        elif f.name.startswith("clubs"): errs += [f"{f.name}: {e}" for e in check_clubs(load(f), cs)]
        elif f.name.startswith("tutorial"):
            en = data_dir.parent / "i18n/en.json"
            errs += [f"{f.name}: {e}" for e in check_tutorial(load(f), load(data_dir / "schema/tutorial.schema.json"), load(en) if en.exists() else None)]
    top = {n: data_dir / f"{n}.json" for n in ("heroes", "players", "clubs")}
    if all(f.exists() for f in top.values()):
        b = load(data_dir / "names/block_list.json")
        block = [x.lower() for x in b["handles"] + b["orgs"] + b["reference_hero_names"]]
        errs += check_world(load(top["heroes"]), load(top["players"]), load(top["clubs"]), block)
    return errs

if __name__ == "__main__":
    errs = validate_dir(sys.argv[1] if len(sys.argv) > 1 else ROOT / "game/data")
    print("\n".join(errs) if errs else "data OK")
    sys.exit(1 if errs else 0)
