"""Regenerate game/tests/golden/rng_vectors.json from tools/pcg32.py.

64-bit values are written as (hi, lo) 32-bit halves because JSON numbers are
doubles in many parsers (Godot included) and cannot hold 64 bits exactly.
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import pcg32 as P

def halves(x):
    return {"hi": x >> 32, "lo": x & 0xFFFFFFFF}

def build():
    cases = []
    g = P.Pcg32(42, 54)
    cases.append({"name": "known_pcg32_demo_42_54", "kind": "u32",
                  "initstate": halves(42), "initseq": halves(54),
                  "u32": [g.next_u32() for _ in range(8)]})
    g = P.Pcg32(0x0123456789ABCDEF, 0xFEDCBA9876543210)
    cases.append({"name": "wide_seed", "kind": "u32",
                  "initstate": halves(0x0123456789ABCDEF), "initseq": halves(0xFEDCBA9876543210),
                  "u32": [g.next_u32() for _ in range(8)]})
    g = P.Pcg32(7, 11)
    cases.append({"name": "floats", "kind": "float",
                  "initstate": halves(7), "initseq": halves(11),
                  "floats": [g.next_float() for _ in range(8)]})
    g = P.Pcg32(7, 11)
    cases.append({"name": "normals", "kind": "normal", "tolerance": 1e-9,
                  "initstate": halves(7), "initseq": halves(11),
                  "normals": [g.next_normal() for _ in range(8)]})
    for text in ["", "match-0001", "lane_top", "teamfight_late"]:
        cases.append({"name": "hash_" + (text or "empty"), "kind": "hash", "text": text,
                      "fnv1a64": halves(P.fnv1a64(text)),
                      "splitmix64_of_fnv": halves(P.splitmix64(P.fnv1a64(text)))})
    ms = P.match_seed(123456789, "match-0001")
    cases.append({"name": "match_seed", "kind": "match_seed",
                  "save_seed": halves(123456789), "match_id": "match-0001",
                  "match_seed": halves(ms)})
    for cid in ["lane_top", "teamfight_late"]:
        s = P.contest_stream(ms, cid)
        cases.append({"name": "contest_" + cid, "kind": "contest",
                      "match_seed": halves(ms), "contest_id": cid,
                      "u32": [s.next_u32() for _ in range(4)]})
    return {"version": 1, "generator": "tools/pcg32.py", "cases": cases}

if __name__ == "__main__":
    out = pathlib.Path(__file__).resolve().parent.parent / "game/tests/golden/rng_vectors.json"
    out.write_text(json.dumps(build(), indent=1) + "\n")
    print("wrote", out)
