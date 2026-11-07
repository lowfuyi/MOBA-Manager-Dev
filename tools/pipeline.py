"""Full pipeline reference (GDD sections 4.4, 5.3, 6, 8): roster + heroes -> AI lineup -> AI draft -> team ratings -> simulation.

Used by tools/pipeline_report.py for the section 9.1 calibration (P-003). Deterministic: every random choice comes from a
named PCG32 stream. Phase 1 simplifications, all documented: Form 0, Morale 60, Fatigue 0, TeamMod fixed (bond baseline),
MetaMod drawn once per run, initial familiarity derived from a hash (v0 rule below).
"""
import itertools, json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import sim_core as S
import comp as COMP
from comp import comp_eval, SYNERGY_PAIRS
from pcg32 import contest_stream, fnv1a64, match_seed

ROOT = pathlib.Path(__file__).resolve().parent.parent
D = ROOT / "game/data"
SLOTS = ("top", "jg", "mid", "bot", "sup")
STATS = ("mec", "sen", "lan", "tft", "mac", "com", "con", "clu")
SLOT_W = {"top": (0.25, 0.15, 0.30, 0.20, 0.10), "jg": (0.15, 0.25, 0.05, 0.20, 0.35), "mid": (0.30, 0.20, 0.25, 0.15, 0.10),
          "bot": (0.35, 0.10, 0.25, 0.25, 0.05), "sup": (0.10, 0.30, 0.10, 0.20, 0.30)}
EARLY_STAT = {"top": "lan", "mid": "lan", "bot": "lan", "jg": "mac", "sup": "sen"}
HEROES = {h["id"]: h for h in json.loads((D / "heroes.json").read_text())}
PLAYERS = {p["id"]: p for p in json.loads((D / "players.json").read_text())}
CLUBS = {c["id"]: c for c in json.loads((D / "clubs.json").read_text())}

DEFAULT_POLICY = {"fam": 0.35, "meta": 0.20, "comp": 0.20, "counter": 0.25, "noise": 0.04}
TEAM_MOD_DEFAULT = 0.0096          # new-club Bond 30, COM 60 (GDD 7.7)
CAL_MORALE = 60.0
FAM_W = 0.06                        # weight of familiarity in HeroFactor (GDD 4.4: 0.90 + 0.10*Fam/100)


def base_rating(p, slot):
    return sum(w * p["stats"][s] for w, s in zip(SLOT_W[slot], STATS[:5]))


def player_fit(p, slot):
    return 1.0 if p["role_primary"] == slot else 0.93 if p.get("role_secondary") == slot else 0.80


def hero_fit(h, slot):
    return 1.0 if h["role_primary"] == slot else 0.95 if h.get("role_secondary") == slot else 0.85


# ---- familiarity v0: hash-derived. Every hero 0..30; each player has 3 signature heroes (50..85) among heroes of his primary role.
_fam_cache = {}
def _u(text):
    return (fnv1a64(text) >> 11) / float(1 << 53)


def familiarity(p, hero_id):
    key = (p["id"], hero_id)
    if key in _fam_cache: return _fam_cache[key]
    if p["id"] not in _sig_cache:
        elig = [h for h in HEROES.values() if h["role_primary"] == p["role_primary"] or h.get("role_secondary") == p["role_primary"]]
        elig.sort(key=lambda h: (_u("sig:%s:%s" % (p["id"], h["id"])), h["id"]))
        _sig_cache[p["id"]] = {h["id"] for h in elig[:3]}
    if hero_id in _sig_cache[p["id"]]:
        v = 50 + 35 * _u("famsig:%s:%s" % key)
    else:
        v = 30 * _u("fam:%s:%s" % key)
    _fam_cache[key] = v
    return v
_sig_cache = {}


def phase_rating(p, slot, hero, phase, fam, meta, morale=CAL_MORALE):
    base = base_rating(p, slot)
    pb = {"early": 0.7 * base + 0.3 * p["stats"][EARLY_STAT[slot]], "mid": base, "late": 0.8 * base + 0.2 * p["stats"]["clu"]}[phase]
    cond = (morale - 50) * 0.06
    hf = ((1.0 - FAM_W) + FAM_W * fam / 100) * (0.90 + 0.10 * min(1.0, p["stats"]["mec"] / (15.0 * hero["difficulty"])))
    fit = player_fit(p, slot) * hero_fit(hero, slot)
    return (pb + cond) * hf * fit * (1 + (hero["power_" + phase] - 50) / 200.0) * meta


def make_meta(seed, spread=0.03):
    return {hid: 1.0 + spread * (2 * _u("meta:%s:%s" % (seed, hid)) - 1) for hid in HEROES}


def best_lineup(club_id):
    """AI lineup rule (GDD 6.x / 3): maximise sum BaseRating*PlayerFit over assignments of 5 of the 10 players."""
    ps = [PLAYERS[i] for i in CLUBS[club_id]["player_ids"]]
    best, best_key = None, None
    for combo in itertools.permutations(range(len(ps)), 5):
        total = sum(base_rating(ps[i], s) * player_fit(ps[i], s) for i, s in zip(combo, SLOTS))
        prim = sum(ps[i]["role_primary"] == s for i, s in zip(combo, SLOTS))
        key = (round(total, 9), prim)
        if best_key is None or key > best_key:
            best, best_key = combo, key
    return {s: ps[i] for i, s in zip(best, SLOTS)}


def team_rating(lineup):
    return sum(base_rating(lineup[s], s) for s in SLOTS) / 5.0


# ---------------- draft
ORDER = [("B", "ban"), ("R", "ban"), ("B", "ban"), ("R", "ban"),
         ("B", "pick"), ("R", "pick"), ("R", "pick"), ("B", "pick"), ("B", "pick"), ("R", "pick"),
         ("R", "ban"), ("B", "ban"),
         ("R", "pick"), ("B", "pick"), ("B", "pick"), ("R", "pick")]


def _progress(heroes):
    """Partial composition value: satisfied needs, synergy, damage balance (positive = good)."""
    tags = [set(h["tags"]) for h in heroes]
    has = lambda t: any(t in ts for ts in tags)
    v = COMP.NEED_PEN * (has("frontline") + (has("engage") or has("pick")) + has("waveclear"))
    for a, b in SYNERGY_PAIRS:
        if any(a in tags[i] and b in tags[j] for i in range(len(heroes)) for j in range(len(heroes)) if i != j):
            v += COMP.SYN_BONUS
    phys = sum(1 if h["damage_type"] == "physical" else 0.5 if h["damage_type"] == "mixed" else 0 for h in heroes)
    mag = sum(1 if h["damage_type"] == "magic" else 0.5 if h["damage_type"] == "mixed" else 0 for h in heroes)
    if phys >= 3.5 or mag >= 3.5: v -= COMP.BAL_PEN
    return v


def _lane_group(slot):
    return "bot" if slot in ("bot", "sup") else slot


def _counter_score(h, slot, enemy_picks):
    g = _lane_group(slot)
    rel = [e for s, e in enemy_picks.items() if _lane_group(s) == g]
    if not rel: return 0.5
    v = sum((e["id"] in h["strong_vs"]) - (h["id"] in e["strong_vs"]) for e in rel)
    return (max(-1, min(1, v)) + 1) / 2


def draft(lineups, meta, mseed, match_id, policies=None):
    """lineups {'B': {slot: player}, 'R': {...}}; policies {'B': dict, 'R': dict}. Returns {'B': {slot: hero}, 'R': ...}."""
    policies = policies or {}
    pol = {t: dict(DEFAULT_POLICY, **policies.get(t, {})) for t in "BR"}
    avail = sorted(HEROES)
    picks = {"B": {}, "R": {}}
    for n, (team, kind) in enumerate(ORDER):
        stream = contest_stream(mseed, "draft:%s:%d" % (match_id, n))
        other = "R" if team == "B" else "B"
        if kind == "ban":
            by_meta_only = stream.next_float() < 0.25
            best, best_v = None, None
            for s, p in lineups[other].items():
                for hid in avail:
                    h = HEROES[hid]
                    v = meta[hid] if by_meta_only else familiarity(p, hid) * meta[hid] * hero_fit(h, s)
                    if best_v is None or v > best_v + 1e-12 or (abs(v - best_v) <= 1e-12 and hid < best):
                        best, best_v = hid, v
            avail.remove(best)
        else:
            w = pol[team]
            cur = [HEROES[h["id"]] for h in picks[team].values()]
            base_prog = _progress(cur) if cur else 0.0
            best, best_v = None, None
            noise = stream.next_normal() * w["noise"]
            for s in SLOTS:
                if s in picks[team]: continue
                p = lineups[team][s]
                for hid in avail:
                    h = HEROES[hid]
                    famf = familiarity(p, hid) / 100.0 * hero_fit(h, s)
                    metaf = (meta[hid] - 0.97) / 0.06
                    comp = max(0.0, min(1.0, 0.5 + (0.1 / COMP.SYN_BONUS) * (_progress(cur + [h]) - base_prog)))
                    ctr = _counter_score(h, s, picks[other])
                    if w.get("value"):
                        # "expert" policy (skill-ceiling probe): rating points the pick adds, plus composition and counters
                        fam = familiarity(p, hid)
                        r = sum(wt * phase_rating(p, s, h, ph, fam, meta[hid]) for ph, wt in (("early", .3), ("mid", .3), ("late", .4)))
                        v = r + w["value_comp"] * (_progress(cur + [h]) - base_prog) + w["value_ctr"] * (ctr - 0.5) * 2
                    else:
                        v = w["fam"] * famf + w["meta"] * metaf + w["comp"] * comp + w["counter"] * ctr
                    if best_v is None or v > best_v + 1e-12 or (abs(v - best_v) <= 1e-12 and (hid, s) < best[::-1]):
                        best, best_v = (s, hid), v
            slot, hid = best
            picks[team][slot] = HEROES[hid]
            avail.remove(hid)
    return picks


# ---------------- team building and match
LANE_MOD = 0.10


def lane_mods(mine, theirs):
    """+5% in a contest where my hero is strong_vs the opposing hero (bot: any link among the pair, capped)."""
    out = {}
    for lane, slot in (("top", "top"), ("mid", "mid"), ("jg", "jg")):
        if theirs[slot]["id"] in mine[slot]["strong_vs"]: out[lane] = LANE_MOD
    links = any(t["id"] in m["strong_vs"] for m in (mine["bot"], mine["sup"]) for t in (theirs["bot"], theirs["sup"]))
    if links: out["bot"] = LANE_MOD
    return out


def build_team(lineup, picks_mine, picks_theirs, meta, team_mod=TEAM_MOD_DEFAULT, con_override=None, neutral_draft=False):
    ratings = {ph: {s: phase_rating(lineup[s], s, picks_mine[s], ph, familiarity(lineup[s], picks_mine[s]["id"]), meta[picks_mine[s]["id"]])
                    for s in SLOTS} for ph in ("early", "mid", "late")}
    mod, style, _ = comp_eval([picks_mine[s] for s in SLOTS])
    con = con_override if con_override is not None else sum(lineup[s]["stats"]["con"] for s in SLOTS) / 5.0
    return {"ratings": ratings, "con": con, "team_mod": team_mod,
            "comp_mod": 0.0 if neutral_draft else mod,
            "lane_mod": {} if neutral_draft else lane_mods(picks_mine, picks_theirs),
            "style": "skirmish" if neutral_draft else style}


def play(club_blue, club_red, save_seed, match_id, meta, policies=None, lineups=None, con=None, neutral_draft=False):
    """Returns dict with a_won (Blue won), final, comp mods, neutral winner if requested."""
    lineups = lineups or {"B": best_lineup(club_blue), "R": best_lineup(club_red)}
    ms = match_seed(save_seed, match_id)
    picks = draft(lineups, meta, ms, match_id, policies)
    con = con or {}
    a = build_team(lineups["B"], picks["B"], picks["R"], meta, con_override=con.get("B"))
    b = build_team(lineups["R"], picks["R"], picks["B"], meta, con_override=con.get("R"))
    r = S.simulate(a, b, ms)
    out = {"blue_won": r["a_won"], "final": r["final"], "comp_b": a["comp_mod"], "comp_r": b["comp_mod"],
           "style_b": a["style"], "style_r": b["style"]}
    if neutral_draft:
        a0 = build_team(lineups["B"], picks["B"], picks["R"], meta, con_override=con.get("B"), neutral_draft=True)
        b0 = build_team(lineups["R"], picks["R"], picks["B"], meta, con_override=con.get("R"), neutral_draft=True)
        out["neutral_blue_won"] = S.simulate(a0, b0, ms)["a_won"]
    return out
