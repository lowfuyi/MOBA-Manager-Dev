"""Content Lead: generated league v0 (task D-008). Writes game/data/players.json and game/data/clubs.json.

Rules (GDD section 12): each stat ~ Normal(50 + 4*club_offset, 8) clamped to 25..90, then a role tilt of
30*(slot weight - 0.2) on the five performance stats for the primary slot (v0 addition: primary players are
actually better at their slot); Potential_stat = stat + U(0, A_age), A_age = 25/22/18/12/8/5 by age band, max 99;
personality even over four; English 100; age 17..32; every player has a primary role, 40% a secondary.
Role guarantee: each club has two primary players per slot. Free agents: 8 per slot, offset -1.0.
All clubs, players and names are fictional; names are screened against game/data/names/block_list.json.
Deterministic: PCG32 seeded below. The runtime generator for new saves is a later port with its own golden test.
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pcg32 import Pcg32

ROOT = pathlib.Path(__file__).resolve().parent.parent
SLOTS = ("top", "jg", "mid", "bot", "sup")
STATS = ("mec", "sen", "lan", "tft", "mac", "com", "con", "clu")
SLOT_W = {  # GDD 4.3: MEC SEN LAN TFT MAC
    "top": (0.25, 0.15, 0.30, 0.20, 0.10), "jg": (0.15, 0.25, 0.05, 0.20, 0.35),
    "mid": (0.30, 0.20, 0.25, 0.15, 0.10), "bot": (0.35, 0.10, 0.25, 0.25, 0.05),
    "sup": (0.10, 0.30, 0.10, 0.20, 0.30)}
PREFIX = ["Ash", "Bri", "Cor", "Dun", "Eld", "Fal", "Gri", "Hol", "Ire", "Jun", "Kor", "Lum", "Mor", "Nyx", "Orm", "Pax",
          "Quo", "Riv", "Sol", "Tal", "Umb", "Vex", "Wren", "Xan", "Yor", "Zel", "Bram", "Cael", "Dov", "Esk"]
SUFFIX = ["bane", "dor", "fin", "gus", "hex", "jin", "kai", "lo", "mir", "nox", "pyre", "rix", "sen", "tor", "vik", "wyn",
          "xo", "zen", "ley", "mont", "ric", "sel"]
COUNTRIES = [("SG", 3), ("MY", 3), ("ID", 3), ("TH", 2), ("VN", 2), ("PH", 2), ("KR", 3), ("JP", 2), ("CN", 3), ("TW", 1),
             ("BR", 2), ("US", 2), ("DE", 1), ("FR", 1), ("SE", 1), ("AU", 1)]
PERSONALITIES = ("professional", "balanced", "casual", "temperamental")
CLUBS = [("ironquill_wolves", "Ironquill Wolves", "KR"), ("duskwater_foxes", "Duskwater Foxes", "SG"),
         ("gildmoor_raiders", "Gildmoor Raiders", "MY"), ("pinehollow_owls", "Pinehollow Owls", "SE"),
         ("mossgate_wardens", "Mossgate Wardens", "DE"), ("northreach_corsairs", "Northreach Corsairs", "BR"),
         ("emberfen_hounds", "Emberfen Hounds", "TH"), ("stormvale_herons", "Stormvale Herons", "JP"),
         ("thornwick_stags", "Thornwick Stags", "US"), ("saltmarrow_gulls", "Saltmarrow Gulls", "ID")]


def load_block():
    b = json.loads((ROOT / "game/data/names/block_list.json").read_text())
    return [x.lower() for x in b["handles"] + b["orgs"] + b["reference_hero_names"]]


def is_blocked(name, block):
    n = name.lower()
    return any(n == x or (len(x) >= 5 and x in n) for x in block)


def clamp(v, lo, hi): return max(lo, min(hi, v))


class Gen:
    def __init__(self):
        self.g = Pcg32(20261107, 7)
        self.block = load_block()
        self.used = set(h["name"].lower() for h in json.loads((ROOT / "game/data/heroes.json").read_text()))
        self.used |= {c[1].lower() for c in CLUBS}
        self.counter = 0

    def uni(self): return self.g.next_float()
    def norm(self): return self.g.next_normal()
    def pick(self, seq): return seq[self.g.next_u32() % len(seq)]

    def weighted(self, pairs):
        total = sum(w for _, w in pairs)
        r = self.uni() * total
        for v, w in pairs:
            r -= w
            if r < 0: return v
        return pairs[-1][0]

    def name(self):
        for _ in range(1000):
            n = self.pick(PREFIX) + self.pick(SUFFIX)
            if n.lower() not in self.used and not is_blocked(n, self.block):
                self.used.add(n.lower())
                return n
        raise RuntimeError("name pool exhausted")

    def age(self):
        return int(clamp(round(23 + 3.5 * self.norm()), 17, 32))

    def potential_room(self, age):
        a = 25 if age <= 19 else 22 if age <= 22 else 18 if age <= 24 else 12 if age <= 26 else 8 if age <= 29 else 5
        return a

    def player(self, club, slot, offset):
        age = self.age()
        mean = 50 + 4 * offset
        stats = {}
        for s in STATS:
            v = mean + 8 * self.norm()
            if s in STATS[:5]:
                v += 30 * (SLOT_W[slot][STATS.index(s)] - 0.2)
            stats[s] = int(clamp(round(v), 25, 90))
        room = self.potential_room(age)
        pot = {s: int(min(99, stats[s] + int(self.uni() * (room + 1)))) for s in STATS}
        sec = None
        if self.uni() < 0.40:
            sec = self.pick([x for x in SLOTS if x != slot])
        self.counter += 1
        return {"id": "p%03d" % self.counter, "name": self.name(), "placeholder": True, "age": age,
                "country": self.weighted(COUNTRIES), "languages": [{"lang": "en", "fluency": 100}],
                "personality": self.pick(PERSONALITIES), "role_primary": slot, "role_secondary": sec,
                "stats": stats, "potential": pot, "club": club}


def build():
    g = Gen()
    players, clubs = [], []
    n = len(CLUBS)
    for i, (cid, cname, country) in enumerate(CLUBS):
        offset = round(-4 + 8 * i / (n - 1), 2)
        ids = []
        for slot in SLOTS:
            for _ in range(2):
                p = g.player(cid, slot, offset)
                players.append(p); ids.append(p["id"])
        clubs.append({"id": cid, "name": cname, "placeholder": True, "strength_offset": offset,
                      "country": country, "player_ids": ids})
    for slot in SLOTS:
        for _ in range(8):
            players.append(g.player(None, slot, -1.0))
    return players, clubs


if __name__ == "__main__":
    ps, cs = build()
    (ROOT / "game/data/players.json").write_text(json.dumps(ps, indent=1) + "\n")
    (ROOT / "game/data/clubs.json").write_text(json.dumps(cs, indent=1) + "\n")
    print("wrote", len(ps), "players,", len(cs), "clubs")
