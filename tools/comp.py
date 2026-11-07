"""Draft composition scoring (GDD section 5.3). Reference implementation for P-003 and later ports.

comp_eval(heroes) -> (comp_mod, style, parts)   heroes: list of 5 hero dicts
"""
SYNERGY_PAIRS = (("engage", "pick"), ("protect", "scaling"), ("poke", "waveclear"), ("frontline", "engage"))


def comp_eval(heroes):
    tags = [set(h["tags"]) for h in heroes]
    has = lambda t: any(t in ts for ts in tags)
    needs = 0.0
    if not has("frontline"): needs -= 0.03
    if not (has("engage") or has("pick")): needs -= 0.03
    if not has("waveclear"): needs -= 0.03
    phys = magic = 0.0
    for h in heroes:
        if h["damage_type"] == "physical": phys += 1
        elif h["damage_type"] == "magic": magic += 1
        else: phys += 0.5; magic += 0.5
    balance = -0.04 if (phys >= 3.5 or magic >= 3.5) else 0.0
    syn = 0.0
    for a, b in SYNERGY_PAIRS:
        # present on two different heroes
        if any(a in tags[i] and b in tags[j] for i in range(len(heroes)) for j in range(len(heroes)) if i != j):
            syn += 0.025
    scores = {
        "dive": sum(("engage" in t) + ("pick" in t) for t in tags),
        "siege": sum(("poke" in t) + ("waveclear" in t) for t in tags),
        "protect": sum(("protect" in t) + ("scaling" in t) for t in tags),
    }
    order = sorted(scores, key=lambda k: -scores[k])
    top, second = scores[order[0]], scores[order[1]]
    style = order[0] if top >= 4 and top >= second + 1 else "skirmish"
    mod = max(-0.10, min(0.10, needs + balance + syn))
    return mod, style, {"needs": needs, "balance": balance, "synergy": syn, "scores": scores}
