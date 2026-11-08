"""HUD text-budget model for UI-PASS-2 6.7.4 (paper model, not measured on a phone).
Rule: admit an item only if no 2.5 s window then holds more than 10 new words; admission order banner, feed, tag, label pair, label (yours only), commentary.
Word counts are assumptions: pair 6.9, yours-only 3.45, feed 5 (short form) or 7, tag 3, short banner 4, wipe banner 2 (replaces the feed line), commentary 8.
Windows are [s, s+2.5). Words are 'new words appearing' at an instant.
Usage: python3 hud_budget.py
"""
import itertools
SPAN = 2.5; CAP = 10
LABELS = [("opening",0.5),("top",5.0),("mid",7.5),("bot",10.0),("jungle",12.5),("plan_check",21.2),
          ("rotation",24.2),("stoneback",31.0),("mid_fight",37.0),("mid_push",46.0),("tempo",51.5),
          ("late_rot",54.5),("moonhulk",57.0),("late_fight",63.5),("close",71.5)]
STAMPS = [13.5,15.75,18.0,20.25,33.75,45.0,60.0,71.25]
FIGHTS = [45.0,71.25]
TAG_SLOTS = STAMPS + [62.0]
PAIR_W = 6.9; MINE_W = 3.45; FEED_W = 5; TAG_W = 3; WIPE_W = 2; BANNER_W = 4; COMM_W = 8
COMM_SLOTS = [(26.75,28.5),(39.5,42.5),(47.5,49.0),(66.0,68.75)]

def max_span(events):
    """events: list of (t, words). max words in any [s, s+SPAN) with s at an event time."""
    best = 0
    for t0, _ in events:
        w = sum(w for t, w in events if t0 <= t < t0 + SPAN)
        best = max(best, w)
    return best

def ok_with(events, new):
    return max_span(events + new) <= CAP

def schedule(feed_w=FEED_W, switch=False, wipes=False, commentary=True, label_move=None):
    ev = []  # admitted (t, words)
    # admission order: banner, feed, tag, intent pair, intent (yours only), commentary
    if switch: ev.append((21.0, BANNER_W))
    for s in STAMPS:
        w = WIPE_W if (wipes and s in FIGHTS) else feed_w
        ev.append((s, w))
    tags_kept = 0
    for s in TAG_SLOTS:
        if ok_with(ev, [(s, TAG_W)]):
            ev.append((s, TAG_W)); tags_kept += 1
    res = {}
    for name, t in LABELS:
        if label_move and name in label_move: t = label_move[name]
        if ok_with(ev, [(t, PAIR_W)]):
            ev.append((t, PAIR_W)); res[name] = "both"
        elif ok_with(ev, [(t, MINE_W)]):
            ev.append((t, MINE_W)); res[name] = "yours"
        else:
            res[name] = "none"
    comm = 0
    if commentary:
        for a, b in COMM_SLOTS:
            t = a
            while t <= b + 1e-9:          # a line may start anywhere inside its slot
                if ok_with(ev, [(t, COMM_W)]):
                    ev.append((t, COMM_W)); comm += 1; break
                t += 0.25
    return ev, res, tags_kept, comm

def items_at_once(events_with_dur):
    pass

def summarise(title, **kw):
    ev, res, tags, comm = schedule(**kw)
    c = {k: sum(1 for v in res.values() if v == k) for k in ("both","yours","none")}
    print(f"{title}: labels both {c['both']}, yours {c['yours']}, none {c['none']}; tags kept {tags}/9; commentary slots usable {comm}/4; max words in a 2.5 s span {max_span(ev)}")
    print("   not both:", {k: v for k, v in res.items() if v != 'both'})
    return res

def unmanaged():
    ev = []
    for _, t in LABELS: ev.append((t, PAIR_W))
    for s in STAMPS: ev.append((s, 7))
    for s in TAG_SLOTS: ev.append((s, TAG_W))
    for s in STAMPS: ev.append((s + 1.0, 7))  # commentary after each stamp
    starts = [k*0.25 for k in range(291)]
    over = 0; worst = (0, 0)
    for s in starts:
        w = sum(w for t, w in ev if s <= t < s + SPAN)
        if w > CAP: over += 1
        if w > worst[0]: worst = (w, s)
    print(f"unmanaged: {over} of {len(starts)} span starts over {CAP}; worst {worst[0]:.1f} words at {worst[1]} s")

if __name__ == "__main__":
    unmanaged()
    summarise("7-word feed, scheduler, no switch, no wipe", feed_w=7)
    summarise("5-word feed, no switch, no wipe", )
    summarise("5-word feed, switch + two wipes", switch=True, wipes=True)
    print("-- P5 (mid push stays at 46.0): the old proposal moved it to 47.5")
    summarise("5-word feed, no switch, mid push at 47.5 (old proposal)", label_move={"mid_push":47.5})
    # how often is the mid push pill dropped, per case
    for name, kw in [("no switch/no wipe", {}), ("switch+wipes", dict(switch=True, wipes=True)),
                     ("wipe at mid fight only", dict(wipes=True))]:
        ev, res, *_ = schedule(**kw)
        print(f"  {name}: mid_push={res['mid_push']}, close={res['close']}, jungle={res['jungle']}, plan_check={res['plan_check']}")
    # four windows starting within 1.5 s after a feed stamp
    near = [(n, t) for n, t in LABELS if any(0 <= t - s <= 1.5 for s in STAMPS)]
    print("pill windows starting 0 to 1.5 s after a feed line:", near)
    # items at once: pair(1)+tag(1)+feed block(1) = 3 by construction; banner leaves 1
